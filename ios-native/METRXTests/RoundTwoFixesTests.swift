import XCTest
@testable import METRX

/// The round-two fixes of 24 Oct 2026 (bug list B, Z and T items) that change numbers or rules (Android
/// RoundTwoFixesTest, same cases and numbers; the older quotes' fingerprint is the iPhone's own).
final class RoundTwoFixesTests: XCTestCase {
    private func dims(_ a: Int, _ b: Int, _ h: Int = 2700) -> [String: Dim] {
        ["A": Dim(v: a), "B": Dim(v: b), "H": Dim(v: h), "T": Dim(v: 200, src: "default")]
    }
    private func room(_ id: String, _ fid: String, _ name: String, _ d: [String: Dim]? = nil) -> Room {
        var r = Room(id: id, floorId: fid, name: name)
        if let d { r.dims = d }
        return r
    }

    /* ---------------- B4: each drawn room keeps its own snap ---------------- */

    // a drawn room a little off square, measured as a 4 × 3 m rectangle: snapped it closes, not snapped it does not
    private let skew = [Pt(x: 0, y: 0), Pt(x: 4000, y: 150), Pt(x: 4000, y: 3000), Pt(x: 0, y: 3000)]
    private func drawn(_ id: String, _ snap: Bool?) -> Room {
        var r = Room(id: id, floorId: "w", name: "X")
        r.template = "poly"; r.shape = "poly"
        var d = Geo.polyDims(4)
        d["A"] = Dim(v: 4000, src: "manual"); d["B"] = Dim(v: 3000, src: "manual")
        d["C"] = Dim(v: 4000, src: "manual"); d["D"] = Dim(v: 3000, src: "manual"); d["H"] = Dim(v: 2700, src: "manual")
        r.dims = d
        r.poly = Poly(verts: skew, snap: snap)
        return r
    }

    func testADrawnRoomIsSolvedWithItsOwnSnapWhateverTheSetting() {
        XCTAssertTrue(Geo.polyGeo(drawn("a", true), false).solved)
        XCTAssertFalse(Geo.polyGeo(drawn("b", false), true).solved)
        // a room with none (an old quote's) takes the one it is given
        XCTAssertTrue(Geo.polyGeo(drawn("c", nil), true).solved)
        XCTAssertFalse(Geo.polyGeo(drawn("d", nil), false).solved)
        XCTAssertEqual(Geo.areas(drawn("e", true), false), Geo.areas(drawn("f", nil), true))
    }

    func testRoomsSavedWithoutASnapTakeTheSettingOnce() {
        var p = Project(id: "p", name: "T")
        p.rooms = [drawn("a", nil), drawn("b", true), room("r", "w", "R", dims(4000, 3000))]
        let q = Store.withSnap(p, false)
        XCTAssertEqual(q.rooms.map { $0.poly?.snap }, [false, true, nil])
        XCTAssertEqual(Store.withSnap(q, true), q)
    }

    /* ---------------- B10: a tray reading keeps the typed limits ---------------- */

    func testAReadingBelowTheLeastIsRefused() {
        let h = Geo.readingLimit("H", 1000, false)
        XCTAssertEqual(h?.0, "err.min"); XCTAssertEqual(h?.1, 1800)
        let a = Geo.readingLimit("A", 300, false)
        XCTAssertEqual(a?.0, "err.min"); XCTAssertEqual(a?.1, 500)
        XCTAssertNil(Geo.readingLimit("A", 300, true))
        let hi = Geo.readingLimit("H", 7000, false)
        XCTAssertEqual(hi?.0, "err.max"); XCTAssertEqual(hi?.1, 6000)
        XCTAssertNil(Geo.readingLimit("H", 2700, false))
    }

    /* ---------------- B11 / corner columns ---------------- */

    func testAColumnInACornerAddsNoWall() {
        var r = room("r", "w", "X", dims(5000, 4000, 3000))
        r.features = [Feature(id: "c", type: "column", wall: "A", off: 1000, w: 400, d: 300)]
        let mid = Geo.areas(r)!
        XCTAssertEqual(mid.perim, 18_000 + 600)
        // flush with corner 1: its side against wall D covers that much of D, so the walls stay 18 m
        r.features = [Feature(id: "c", type: "column", wall: "A", off: 0, w: 400, d: 300)]
        let corner = Geo.areas(r)!
        XCTAssertEqual(corner.perim, 18_000); XCTAssertEqual(corner.gross, 18_000 * 3000)
        // the floor the plan cards show is the same, less the column
        XCTAssertEqual(corner.floor, 20_000_000 - 400 * 300)
    }

    /* ---------------- B13 and B4: the fingerprint of quotes issued before ---------------- */

    private func snapOf(_ rooms: [Room], snap: Bool = true, calc: [Room] = [], elec: ElecOrder? = nil, tiles: [TileLayout]? = nil) -> Snap {
        Snap(name: "Order", rooms: rooms.map { SnapRoom(room: $0, floorLabel: "W") }, snap: snap, elec: elec,
             calcRooms: calc.map { SnapRoom(room: $0, floorLabel: "W") }, tiles: tiles)
    }
    private func dev(_ room: String, _ off: Int) -> ElecDev { ElecDev(id: "d", t: "s1", roomId: room, wall: "A", off: off, h: 300) }

    func testARoomsOwnSnapKeepsAnOlderQuoteMatching() {
        let old = fingerprint(snapOf([drawn("a", nil)]))
        XCTAssertEqual(fingerprint(snapOf([drawn("a", true)])), old)
        // the setting turned off later: the rooms drawn with it on still match
        XCTAssertEqual(fingerprint(snapOf([drawn("a", true)], snap: false)), old)
        // an older quote made with it off still matches its rooms kept off
        XCTAssertEqual(fingerprint(snapOf([drawn("a", false)], snap: true)), fingerprint(snapOf([drawn("a", nil)], snap: false)))
        // a room drawn the other way than the rest is not the same
        XCTAssertNotEqual(fingerprint(snapOf([drawn("a", true), drawn("b", nil)])), fingerprint(snapOf([drawn("a", true), drawn("b", false)])))
    }

    func testRoomsLeftOutCountOnlyWithTheTradesThingsInThem() {
        let shown = room("s", "w", "S", dims(4000, 3000)), out = room("o", "w", "O", dims(3000, 3000))
        let inShown = ElecOrder(devs: [dev("s", 1000)])
        XCTAssertEqual(fingerprint(snapOf([shown], elec: inShown)), fingerprint(snapOf([shown], calc: [out], elec: inShown)))
        let inOut = ElecOrder(devs: [dev("o", 1000)])
        XCTAssertNotEqual(fingerprint(snapOf([shown], elec: inOut)), fingerprint(snapOf([shown], calc: [out], elec: inOut)))
    }

    func testTheTileLayoutsAreInTheFingerprint() {
        let r = room("s", "w", "S", dims(4000, 3000))
        XCTAssertEqual(fingerprint(snapOf([r])), fingerprint(snapOf([r], tiles: [])))
        let l = TileLayout(id: "l", roomId: "s")
        var diag = l
        diag.pattern = "diag"
        XCTAssertNotEqual(fingerprint(snapOf([r], tiles: [l])), fingerprint(snapOf([r], tiles: [diag])))
        // a tiler's quote issued before the layouts were in it still matches its unchanged draft
        let sn = snapOf([r], tiles: [l])
        XCTAssertTrue(sameAsQuote(sn, fingerprint(sn, legacy: true)))
    }

    func testATradesThingsAreInTheFingerprintAndOlderQuotesStillMatch() {
        let shown = room("s", "w", "S", dims(4000, 3000)), out = room("o", "w", "O", dims(3000, 3000))
        let sn = snapOf([shown], calc: [out], elec: ElecOrder(devs: [dev("s", 1000)]))
        let moved = snapOf([shown], calc: [out], elec: ElecOrder(devs: [dev("s", 1500)]))
        XCTAssertNotEqual(fingerprint(sn), fingerprint(moved))
        // a quote issued before (its fingerprint with the empty room left out in it) still matches its unchanged draft
        let older = fingerprint(sn, legacy: true)
        XCTAssertNotEqual(older, fingerprint(sn))
        XCTAssertTrue(sameAsQuote(sn, older))
        XCTAssertTrue(sameAsQuote(sn, fingerprint(sn)))
        XCTAssertFalse(sameAsQuote(moved, fingerprint(sn)))
        XCTAssertFalse(sameAsQuote(moved, older))
    }

    func testAnOlderQuoteSaysBothNameAndArea() throws {
        let sn = try JSONDecoder().decode(Snap.self, from: Data(#"{"name":"x"}"#.utf8))
        XCTAssertEqual(sn.roomLabel, "both")
    }

    /* ---------------- Z1 / Z2: handles ---------------- */

    private let ws = Workshop()
    private func piece(_ id: String) -> Furniture { pieceOf(fModel(id)!, [:], ws, id) }

    func testChangeForAllHandlesStayWhenAPieceOfSeveralBoxesIsResized() {
        let st = swapAll([piece("stenka")], handle: "handleKnob")[0]
        let w = pieceVals(st, ws)["w"] ?? 0
        let big = pieceResized(st, ["w": w + 400], ws)
        XCTAssertEqual(big.handle, "handleKnob"); XCTAssertEqual(commonHandle([big]), "handleKnob")
        let none = swapAll([st], handle: NO_HANDLES)[0]
        XCTAssertFalse(hasHandles(pieceResized(none, ["w": w + 400], ws)))
    }

    func testNoHandlesIsSeenWithAFridgeSpaceInTheKitchen() {
        var k = piece("L")
        k.modules.append(Module(id: "g", type: "gap", w: 600, h: 2000, d: 650, wall: k.modules[0].wall, fronts: Fronts("open", 0), legs: false, app: "fridge"))
        let none = swapAll([k], handle: NO_HANDLES)
        XCTAssertEqual(commonHandle(none), NO_HANDLES)
        XCTAssertFalse(hasHandles(none[0]))
        XCTAssertTrue(hasHandles(k))
    }

    /* ---------------- Z3 / Z4 / Z5: remnants ---------------- */

    func testATakenRemnantStaysTakenAndLocked() {
        let store = [Remnant("t", "ldsp16w", 800, 500, src: "o0", used: "gone"), Remnant("f", "ldsp16w", 800, 500, src: "o0")]
        // the order that took it was deleted: still not free
        XCTAssertEqual(remnantsFor(store, "o2", false).map(\.id), ["f"])
        XCTAssertFalse(removable(store[0])); XCTAssertTrue(removable(store[1]))
    }

    func testAnOrdersCutIsNotUndoneOnceAnotherTookItsOffcutAndNoneIsAddedTwice() {
        var n = 0
        let ids: () -> String = { n += 1; return "r\(n)" }
        let f = piece("dresser")
        let lays = costOf([f], ws, MAT_PRESETS, HW_PRESETS).layouts
        let cut = cutDone([], lays, MAT_PRESETS, "o1", 300, 1, ids)
        let mine = cut.filter { $0.src == "o1" }
        XCTAssertFalse(mine.isEmpty); XCTAssertTrue(canUndoCut(cut, "o1"))
        // another order takes one of them
        let taken: [Remnant] = cut.map { r in
            if r.id != mine[0].id { return r }
            var g = r; g.used = "o2"
            return g
        }
        XCTAssertFalse(canUndoCut(taken, "o1"))
        // cut again (as after an Undo that was refused before): the taken one is not made a second time
        let again = cutDone(taken, lays, MAT_PRESETS, "o1", 300, 2, ids)
        XCTAssertEqual(again.count, cut.count)
        XCTAssertEqual(again.filter { $0.mat == mine[0].mat && $0.L == mine[0].L && $0.W == mine[0].W && $0.used == "o2" }.count, 1)
    }

    /* ---------------- Z6 / Z10 ---------------- */

    func testEndPanelsBelongToNoModule() {
        var k = piece("L")
        k.kx = KExtras(ends: 2, endsUp: 1)
        XCTAssertFalse(extrasParts(k, ws).isEmpty)
        XCTAssertTrue(extrasParts(k, ws).allSatisfy { $0.mod == "" })
    }

    func testOneShelfRuleForTheDesignerAndTheCheckList() {
        XCTAssertEqual(shelfSpanMax(18), 1100); XCTAssertEqual(shelfSpanMax(16), 1000)
        XCTAssertFalse(shelfTooLong(1050, 18)); XCTAssertTrue(shelfTooLong(1050, 16))
        XCTAssertFalse(shelfTooLong(1102, 18)); XCTAssertTrue(shelfTooLong(1103, 18))
    }

    /* ---------------- T1: a typed-room-only plumber's order ---------------- */

    func testATypedRoomOnlyOrderIsNotAskedForARiser() {
        var p = Project(id: "p", name: "T")
        p.industry = "plumb"
        p.plumb = PlumbOrder(free: [PlFree(id: "f", name: "@sx.k.bath")])
        XCTAssertTrue(needsRiser(p))
        XCTAssertNil(riserToPlace(p, true))
        XCTAssertFalse(plumbCalcOf(p, true).warns.contains { $0.key == "sx.w.noRiser" })
    }

    func testAnOlderTypedRoomTakesItsKitsChoices() {
        let f = PlFree(id: "f", name: "", kind: "bath", bath: 0, shower: 1, kit: "bt.cabin")
        XCTAssertTrue(pWithKit(f).cabin)
        var kept = f
        kept.kept = true
        XCTAssertFalse(pWithKit(kept).cabin)
    }

    /* ---------------- T2 / T4: tiles ---------------- */

    func testAWallHeightTypedWrongIsNotSaved() {
        XCTAssertTrue(surfHeightsOk(TSurf(id: "A")))
        XCTAssertFalse(surfHeightsOk(TSurf(id: "A", mode: "to", h1: 0))); XCTAssertTrue(surfHeightsOk(TSurf(id: "A", mode: "to", h1: 1500)))
        XCTAssertFalse(surfHeightsOk(TSurf(id: "A", mode: "band", h0: 900, h1: 0))); XCTAssertFalse(surfHeightsOk(TSurf(id: "A", mode: "band", h0: 0, h1: 1500)))
        XCTAssertTrue(surfHeightsOk(TSurf(id: "A", mode: "band", h0: 900, h1: 1500)))
    }

    func testTheSameTileAtTwoPricesIsTwoLines() {
        func need(_ price: String) -> TileNeed {
            TileNeed(look: "plain", a: 300, b: 600, whole: 10, cut: 2, reused: 0, tiles: 12, skirtTiles: 0, spare: 10, withSpare: 14, perBox: 8, boxes: 2, m2: 2.0, price: price)
        }
        XCTAssertEqual((TileCount(needs: [need("100")]) + TileCount(needs: [need("200")])).needs.count, 2)
        XCTAssertEqual((TileCount(needs: [need("100")]) + TileCount(needs: [need("100")])).needs.count, 1)
    }

    /* ---------------- T5 / T8 / T9 ---------------- */

    func testUndoPutsBackOnlyTheDeletedItem() {
        XCTAssertEqual(["a", "c"].putBack("b", at: 1), ["a", "b", "c"])
        XCTAssertEqual(["a"].putBack("x", at: 5), ["a", "x"])
    }

    func testAWindowIsNotMadeSmallerThanItsSashesTake() {
        let w3 = wNewItem("w", wkind("w3"))
        let a = wMinSize(w3)
        XCTAssertEqual(a.0, 450); XCTAssertEqual(a.1, 300)
        var tall = w3
        tall.cols = [WCol(w: 700, rows: [WCell(h: 400), WCell(h: 400), WCell(h: 400)])]
        let b = wMinSize(tall)
        XCTAssertEqual(b.0, 300); XCTAssertEqual(b.1, 450)
    }

    func testTheNextStepSeesEveryRoomOfAWorkspace() {
        var p = Project(id: "p", name: "T")
        p.floors = [Workspace(id: "w1", name: "1"), Workspace(id: "w2", name: "2")]
        p.rooms = [room("a", "w1", "A"), room("b", "w1", "B"), room("c", "w2", "C")]
        XCTAssertEqual(roomsByWorkspace(p).map { $0.1.id }, ["a", "b", "c"])
    }

    /* ---------------- T10: typed electric rooms keep the kit's lights ---------------- */

    func testATypedRoomKeepsItsWallLightsStripsAndSocketHeights() {
        let bath = kitOf("bt.std")!
        let f = freeOf(bath, defaultOpts(bath), "b", "", 2500, 2000, 2700)
        XCTAssertEqual(f.lamps, ["lw"])
        XCTAssertTrue(f.sockH.contains(1000))
        var p = Project(id: "p", name: "T")
        p.industry = "elec"
        p.elec = ElecOrder(free: [f])
        let cs = ctxs(p, true)
        XCTAssertEqual(cs.count, 1)
        let ds = devsIn(p, cs[0])
        XCTAssertEqual(ds.filter { $0.t == "lw" }.count, 1)
        XCTAssertTrue(ds.contains { $0.t == "sw" && $0.h == 1000 })
        let kit = kitOf("kt.std")!
        let k = freeOf(kit, defaultOpts(kit), "k", "", 4000, 3000, 2700)
        XCTAssertEqual(k.lamps, ["led"])
        var pk = Project(id: "p", name: "T")
        pk.industry = "elec"
        pk.elec = ElecOrder(free: [k])
        let ck = ctxs(pk, true)
        XCTAssertEqual(ck.count, 1)
        XCTAssertEqual(devsIn(pk, ck[0]).filter { $0.t == "led" }.count, 1)
    }
}
