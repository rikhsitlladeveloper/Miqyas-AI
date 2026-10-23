import XCTest
@testable import METRX

/// The gallery's later models (Pieces.swift, Items.swift, Cabinets.swift; Android PiecesTest): their steps, pieces of
/// several boxes, where the boxes go, how they are placed.
final class PiecesTests: XCTestCase {
    private let ws = Workshop()
    private let newer = ["dining", "bar", "pantry", "cornerW", "bed", "vanity", "shelfW", "tvBed", "stenka", "vitrina", "coffee", "shelvesW",
                         "shoe", "hallW", "mirrorP", "bunk", "loft", "kidsW", "toys", "cornerDesk", "bookcase", "officeC", "sinkV", "mirrorC", "penal", "washer"]
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }

    /// The one part of key (it must be there once).
    private func one(_ ps: [FPart], _ key: String, file: StaticString = #filePath, line: UInt = #line) -> FPart? {
        let found = ps.filter { $0.key == key }
        XCTAssertEqual(found.count, 1, key, file: file, line: line)
        return found.first
    }

    private func qty(_ ps: [FPart], _ key: String) -> Int { ps.filter { $0.key == key }.reduce(0) { $0 + $1.qty } }

    func testEveryNewerModelIsInTheGalleryWithItsRoom() {
        let ids = GALLERY.flatMap { $0.1 }
        for id in newer { XCTAssertTrue(ids.contains(id), id) }
        XCTAssertEqual(GALLERY.first { $0.0 == "kids" }?.1, ["bunk", "loft", "kidsW", "toys"])
        XCTAssertEqual(GALLERY.first { $0.0 == "bath" }?.1, ["sinkV", "mirrorC", "penal", "washer"])
    }

    func testEveryNewerModelHasPartsHardwareAndAPriceAndGivesBackItsSizes() {
        for id in newer {
            let m = fModel(id)!
            let f = piece(id)
            XCTAssertEqual(f.kind, "wardrobe", id); XCTAssertEqual(f.type, id, id); XCTAssertEqual(kindKey(f), "other", id)
            XCTAssertFalse(boxes(f).isEmpty, id)
            XCTAssertFalse(cutList([f], ws).isEmpty, id)
            XCTAssertFalse(hardware([f], ws).pairs.isEmpty, id)
            XCTAssertEqual(costOf([f], ws, MAT_PRESETS, HW_PRESETS).missing, 0, id)
            // what was asked comes back as asked
            let v = valsOf(f, ws)
            for s in stepsOf(m) { XCTAssertEqual(v[s.key], s.usual, "\(id) \(s.key)") }
            // the cabinets pass the wardrobe checks (as in a room just big enough)
            for b in f.modules where b.type == "wardrobe" {
                let c = wardrobeChecks(b, b.x + b.w + 20, 3000, ws, [], [])
                XCTAssertFalse(c.contains { $0.level == "err" }, "\(id): \(c.filter { $0.level == "err" }.map(\.key))")
            }
        }
    }

    func testChoicesAreStepsOfTheirOwn() {
        let bed = stepsOf(fModel("bed")!)
        XCTAssertEqual(bed.map(\.key), ["bt", "mw", "ml", "h", "hb"])
        XCTAssertTrue(bed[0].choice); XCTAssertEqual(bed[0].opts.count, 3)
        XCTAssertEqual(bed[1].picks, [900, 1200, 1400, 1600, 1800])
        XCTAssertNil(stepIssue(bed[0], 2))
        XCTAssertEqual(stepIssue(bed[0], 3)?.0, "fx.max"); XCTAssertEqual(stepIssue(bed[0], 3)?.1, 2)
        XCTAssertEqual(stepsOf(fModel("loft")!).map(\.key), ["mw", "ml", "h", "lad", "und"])
        XCTAssertEqual(stepsOf(fModel("bunk")!)[0].picks, [800, 900])
        XCTAssertEqual(stepsOf(fModel("dining")!).map(\.key), ["w", "d", "h", "lg", "tp", "rc"])
        XCTAssertEqual(stepsOf(fModel("mirrorC")!).map(\.key), ["w", "h", "d", "e"])
        XCTAssertEqual(stepsOf(fModel("sinkV")!).map(\.key), ["w", "h", "d", "mt"])
        // the shape and which sides were measured come first (bazis ideas, 23 Oct 2026)
        XCTAssertEqual(stepsOf(fModel("cornerW")!).map(\.key), ["sh", "ms", "w", "w2", "h", "d"])
    }

    func testABedIsBuiltRoundItsMattressAndItsKindIsChosen() {
        let f = piece("bed", ["bt": 1, "mw": 1400, "ml": 2000])
        let m = wardOfF(f)!
        XCTAssertEqual(m.type, "bed"); XCTAssertEqual(m.opt?.bed, "drawers")
        XCTAssertEqual(m.w, 1400 + 2 * ws.t + 10); XCTAssertEqual(m.d, 2000 + 2 * ws.t + 10); XCTAssertEqual(m.h, 450)
        // a 1400 mattress has drawers on both sides, two a side
        XCTAssertEqual(bedDrawers(m, ws).count, 4)
        XCTAssertEqual(qty(partsOf(m, ws), "fp.dFace"), 4)
        XCTAssertEqual(hardwareOf(m, ws)["runner"], 4)
        let hb = one(partsOf(m, ws), "fp.headboard")
        XCTAssertEqual(hb?.qty, 1); XCTAssertEqual(hb?.L, m.w); XCTAssertEqual(hb?.W, 1000)
        // a narrow one only on its right side
        XCTAssertEqual(bedDrawers(wardOfF(piece("bed", ["bt": 1, "mw": 900]))!, ws).map(\.side), [1, 1])
        // lift-up: a mechanism and a box bottom, no slatted base bought apart
        let lift = wardOfF(piece("bed", ["bt": 2]))!
        XCTAssertEqual(hardwareOf(lift, ws)["bedLift"], 1); XCTAssertNil(hardwareOf(lift, ws)["bedBase"])
        XCTAssertTrue(partsOf(lift, ws).contains { $0.key == "fp.boxBottom" })
        // on legs: legs, a slatted base
        let legs = wardOfF(piece("bed"))!
        XCTAssertTrue((hardwareOf(legs, ws)["leg"] ?? 0) >= 4); XCTAssertEqual(hardwareOf(legs, ws)["bedBase"], 1)
        // new sizes keep the kind; the frame follows the mattress
        let g = resized(f, ["mw": 1800, "hb": 1200], ws)
        let gm = wardOfF(g)!
        XCTAssertEqual(gm.w, 1800 + 2 * ws.t + 10); XCTAssertEqual(gm.opt?.bed, "drawers"); XCTAssertEqual(gm.opt?.hb, 1200)
        XCTAssertEqual(itemTop(gm, ws), 1200)
    }

    func testBunkAndLoftBedsStandAlongTheWallWithTheirLadder() {
        let b = wardOfF(piece("bunk", ["lad": 0]))!
        XCTAssertEqual(b.w, 2000 + 2 * ws.t + 10); XCTAssertEqual(b.d, 900 + 2 * ws.t + 10 + LADDER_D)
        XCTAssertEqual(b.opt?.ladder, "L")
        XCTAssertEqual(hardwareOf(b, ws)["bedBase"], 2)
        XCTAssertTrue(partsOf(b, ws).contains { $0.key == "fp.rung" })
        XCTAssertEqual(one(partsOf(b, ws), "fp.ladder")?.qty, 2)
        // a loft bed with a desk, a cabinet or nothing under it, always under its platform and inside its frame
        let desk = piece("loft")
        XCTAssertEqual(desk.modules.map(\.type), ["loft", "wardrobe"])
        let bed = desk.modules[0]
        let ward = withUnder(desk, "ward", ws)
        let u = ward.modules[1]
        XCTAssertTrue(topOf(u, ws) <= upperDeck(bed) - 150)
        XCTAssertTrue(u.x >= bed.x && u.x + u.w <= bed.x + bed.w)
        XCTAssertTrue(u.sections.allSatisfy { $0.fronts.kind == "door" })
        XCTAssertEqual(withUnder(desk, "open", ws).modules.count, 1)
        XCTAssertEqual(wardOfF(withUnder(desk, "open", ws))?.opt?.under, "open")
    }

    func testTablesHaveTheirLegsAndTop() {
        let board = wardOfF(piece("dining"))!
        XCTAssertEqual(one(partsOf(board, ws), "fp.tLeg")?.qty, 2)
        XCTAssertEqual(one(partsOf(board, ws), "fp.top")?.qty, 2)                 // a dining top of two glued layers
        let metal = wardOfF(piece("dining", ["lg": 1]))!
        XCTAssertEqual(hardwareOf(metal, ws)["tableLeg"], 4); XCTAssertFalse(partsOf(metal, ws).contains { $0.key == "fp.tLeg" })
        XCTAssertEqual(hardwareOf(wardOfF(piece("coffee", ["lg": 2]))!, ws)["tableFrame"], 1)
        let round = wardOfF(piece("coffee", ["rc": 1]))!
        XCTAssertTrue(partsOf(round, ws).contains { $0.key == "fp.topR" })
        XCTAssertEqual(one(partsOf(round, ws), "fp.topR")?.qty, 1)                // a coffee table's top is one board
        // a worktop top is bought by the metre, not cut
        let wt = piece("dining", ["tp": 1])
        XCTAssertFalse(partsOf(wardOfF(wt)!, ws).contains { $0.key == "fp.top" })
        let wtLines = costOf([wt], ws, MAT_PRESETS, HW_PRESETS).lines.filter { $0.key == "wt38" }
        XCTAssertEqual(wtLines.count, 1)
        XCTAssertEqual(wtLines.first?.qty ?? 0, 1.4, accuracy: 1e-9)
        XCTAssertTrue(canStandFree(wt))
    }

    func testTheBarCounterAndTheMirrorPanel() {
        let bar = wardOfF(piece("bar"))!
        XCTAssertEqual(hardwareOf(bar, ws)["barRail"], 1420)
        XCTAssertTrue(partsOf(bar, ws).contains { $0.key == "fp.barFront" })
        let panel = wardOfF(piece("mirrorP"))!
        XCTAssertEqual(panel.type, "hooks"); XCTAssertEqual(panel.elev, 300); XCTAssertTrue(hung(panel))
        XCTAssertEqual(hardwareOf(panel, ws)["hook"], 4); XCTAssertEqual(hardwareOf(panel, ws)["mirror"], 450 * 1000)
        XCTAssertEqual(topOf(panel, ws), 300 + 1600 + ws.t)
    }

    func testAStenkaIsItsPiecesSideBySideWithAShelfOverTheTvUnit() {
        let f = piece("stenka")
        let bs = boxes(f)
        XCTAssertEqual(bs.count, 4)
        let floor = bs.filter { !hung($0) }
        for i in 0..<(floor.count - 1) { XCTAssertEqual(floor[i].x + floor[i].w, floor[i + 1].x) }
        XCTAssertEqual(runLen(f), 3000)
        let tv = floor[1], shelf = bs.first { hung($0) }!
        XCTAssertEqual(bs.filter { hung($0) }.count, 1)
        XCTAssertEqual(shelf.x, tv.x + (tv.w - shelf.w) / 2)
        // another tall cabinet after the TV unit: the rest move along, the shelf stays over the TV unit
        var more = f
        more.modules.insert(stenkaPart(f, "tall", ws), at: 2)
        let g = packPiece(more, ws: ws)
        XCTAssertEqual(runLen(g), 3600)
        let gf = boxes(g).filter { !hung($0) }
        for i in 0..<(gf.count - 1) { XCTAssertEqual(gf[i].x + gf[i].w, gf[i + 1].x) }
        XCTAssertEqual(boxRole(g, boxes(g).first { hung($0) }!), "pc.shelf")
        XCTAssertEqual(boxRole(g, boxes(g)[0]), "pc.tall")
    }

    func testACornerWardrobeTakesTwoWallsAndClosesItsCorner() {
        let f = piece("cornerW")
        XCTAssertEqual(f.walls, ["A", "B"])
        let a = f.modules.filter { $0.wall == "A" }, b = f.modules.filter { $0.wall == "B" }
        XCTAssertEqual(a.count, 2); XCTAssertEqual(b.count, 1)
        let corner = a[a.count - 1]
        XCTAssertEqual(corner.sections.count, 1)
        XCTAssertEqual(corner.sections.first?.blind, 600)
        XCTAssertEqual(boxRole(f, corner), "pc.corner"); XCTAssertEqual(boxRole(f, b[0]), "pc.armB")
        // its door covers the open part only
        let door = one(partsOf(corner, ws), "fp.door")
        XCTAssertEqual(door?.qty, 1)
        XCTAssertEqual(door?.W, (400 * 10 - 2 * ws.edge10) / 10)
        // the second arm starts past the first's depth
        XCTAssertEqual(b[0].x, corner.d)
        // in a room: it goes into the corner of the walls it is put on, its first arm ending there
        var room = Room(id: "r", floorId: "w", name: "Xona")
        room.dims = ["A": Dim(v: 3600), "B": Dim(v: 3000), "H": Dim(v: 2700)]
        XCTAssertEqual(placeWalls(f, ["A", "B", "C", "D"], "C"), ["C", "D"])
        let lens: (String) -> Int? = { ["A": 3600, "B": 3000][$0] }
        let g = placed(f, ["A", "B"], "r", "w", len: lens)
        XCTAssertEqual(g.modules.filter { $0.wall == "A" }.map { $0.x + $0.w }.max(), 3600 - W_GAP_SIDE)
        XCTAssertTrue(fitIssues(g, ["A", "B"], lens, 2700, ws).isEmpty)
        let short = fitIssues(g, ["A", "B"], { ["A": 1500, "B": 3000][$0] }, 2700, ws)
        XCTAssertEqual(short.map(\.key), ["fz.wide"])
        let walls = planWalls(room, true)
        XCTAssertEqual(footsOf(g, walls, ws).count, 3)
        XCTAssertTrue(placeWarnings(g, [], room, walls, ws).isEmpty)
        // taken out again: the corner layout stays
        let t = takenOut(g, lens, 2700)
        XCTAssertEqual(t.modules.filter { $0.wall == "A" }.map(\.x).min(), W_GAP_SIDE)
        XCTAssertEqual(t.modules.filter { $0.wall == "B" }.map(\.x), [corner.d])
    }

    func testACornerDeskGoesRoundTheCornerWithItsKneeSpace() {
        let f = piece("cornerDesk")
        let a = f.modules[0], b = f.modules[1]
        XCTAssertTrue(hasKnee(a) && hasKnee(b))
        XCTAssertFalse(b.sideL)                                       // its knee space runs on under the first arm's top
        XCTAssertEqual(b.sections.first?.knee, true)
        XCTAssertEqual(valsOf(f, ws)["w2"], 1200)
    }

    func testAVitrinaAndAWasherColumnAreOneBoxOnAnother() {
        let v = piece("vitrina")
        let lo = v.modules[0], up = v.modules[1]
        XCTAssertEqual(up.elev, topOf(lo, ws)); XCTAssertEqual(up.x, lo.x); XCTAssertEqual(up.w, lo.w)
        XCTAssertEqual(up.sections.count, 1)
        XCTAssertEqual(up.sections.first?.face, "glass"); XCTAssertTrue(up.led)
        XCTAssertTrue(up.sections[0].inserts.allSatisfy { $0.kind == "glass" })
        let hw = hardwareOf(up, ws)
        XCTAssertTrue((hw["glassDoor"] ?? 0) > 0 && (hw["glassShelf"] ?? 0) > 0)
        XCTAssertEqual(hw["led"], up.w - 2 * ws.t); XCTAssertEqual(hw["ledPsu"], 1)
        XCTAssertFalse(partsOf(up, ws).contains { $0.key == "fp.door" })   // its doors are bought, not cut
        // the box just changed leads: a wider upper one widens the lower
        var up2 = up; up2.w = 1000
        var v2 = v; v2.modules = [lo, up2]
        XCTAssertEqual(stackPack(v2, up.id, ws).modules[0].w, 1000)
        let w = piece("washer")
        XCTAssertEqual(w.modules[0].sections.first?.knee, true)              // the machine's niche: no bottom, no back
        XCTAssertFalse(partsOf(w.modules[0], ws).contains { $0.key == "fp.back" || $0.key == "fp.plinth" })
        XCTAssertEqual(w.modules[1].elev, 900)
    }

    func testADressingTableHasItsMirrorOverIt() {
        let f = piece("vanity", ["rw": 700, "rh": 900])
        let cab = f.modules[0]
        let mirs = f.modules.filter { $0.type == "mirror" }
        XCTAssertEqual(mirs.count, 1)
        let mir = mirs[0]
        XCTAssertTrue(hasKnee(cab))
        XCTAssertEqual(mir.x, cab.x + (cab.w - 700) / 2); XCTAssertEqual(mir.h, 900)
        XCTAssertTrue(mir.elev >= topOf(cab, ws) + 50)
        XCTAssertEqual(hardwareOf(mir, ws)["mirror"], 700 * 900)
        XCTAssertEqual(wardOfF(f), cab)
        let g = resized(f, ["w": 1200, "rw": 800], ws)
        XCTAssertEqual(g.modules[0].w, 1200)
        XCTAssertEqual(g.modules.first { $0.type == "mirror" }?.x, g.modules[0].x + (1200 - 800) / 2)
    }

    func testBathroomPiecesAreOfMoistureResistantBoardAndHangOrStand() {
        XCTAssertTrue(MAT_PRESETS.contains { $0.id == MR_BOARD })
        for t in BATH_TYPES { XCTAssertEqual(piece(t).mats.carcass, MR_BOARD, t) }
        let legs = wardOfF(piece("sinkV"))!
        XCTAssertTrue(legs.legs); XCTAssertEqual(topOf(legs, ws), 850)
        let wall = wardOfF(piece("sinkV", ["mt": 1]))!
        XCTAssertTrue(hung(wall)); XCTAssertEqual(wall.elev, 300); XCTAssertEqual(topOf(wall, ws), 850)
        XCTAssertEqual(hardwareOf(wall, ws)["hanger"], 2); XCTAssertNil(hardwareOf(wall, ws)["leg"])
        XCTAssertFalse(partsOf(wall, ws).contains { $0.key == "fp.plinth" })
        let mc = wardOfF(piece("mirrorC"))!
        XCTAssertEqual(mc.elev, 1250); XCTAssertEqual(mc.sections.first?.face, "mirror"); XCTAssertFalse(mc.handles)
        XCTAssertTrue((hardwareOf(mc, ws)["mirror"] ?? 0) > 0)
        XCTAssertEqual(valsOf(resized(piece("mirrorC"), ["e": 1300], ws), ws), ["w": 600, "h": 700, "d": 150, "e": 1300])
    }

    func testABedStandsWithItsHeadboardOnAWallAndItsDrawersNeedRoom() {
        var room = Room(id: "r", floorId: "w", name: "Xona")
        room.dims = ["A": Dim(v: 4000), "B": Dim(v: 3500), "H": Dim(v: 2700)]
        let walls = planWalls(room, true)
        let f = placed(piece("bed", ["bt": 1]), ["A"], "r", "w", off: 1000)
        let feet = footsOf(f, walls, ws)
        XCTAssertEqual(feet.count, 1)
        let ft = feet[0]
        XCTAssertEqual(ft.wall, "A"); XCTAssertEqual(ft.a0, 1000, accuracy: 1e-9); XCTAssertEqual(ft.a1, 1000 + Double(wardOfF(f)!.w), accuracy: 1e-9)
        XCTAssertTrue(canStandFree(f))
        // its drawers pull out from both long sides
        XCTAssertEqual(swingsOf(f, walls, ws).count, 4)
        // a wardrobe right beside it is in the way of the drawers
        let w = placed(newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws), ["A"], "r", "w", off: 1000 + wardOfF(f)!.w + 20)
        XCTAssertTrue(placeWarnings(f, [w], room, walls, ws).contains { $0.key == "fz.doorsHit" })
        // dragged into the room and turned it stands on no wall
        var p = f; p.pose = Pose("A", 2500, 900, 90)
        let pf = footsOf(p, walls, ws)
        XCTAssertEqual(pf.count, 1); XCTAssertNil(pf.first?.wall)
        XCTAssertFalse(placeWarnings(p, [], room, walls, ws).contains { $0.key == "fz.outside" })
        // a hung shelf is off the floor
        let sh = placed(piece("shelfW"), ["B"], "r", "w")
        let sf = footsOf(sh, walls, ws)
        XCTAssertEqual(sf.count, 1); XCTAssertEqual(sf.first?.floor, false); XCTAssertEqual(sf.first?.lo, 1500)
    }
}
