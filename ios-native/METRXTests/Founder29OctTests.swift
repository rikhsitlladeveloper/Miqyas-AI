import XCTest
@testable import METRX

/// The founder's five changes of 29 Oct 2026 (Android does the same): the gorka bridge's default doors, a wall-hung
/// piece's box size and its own "poldan" line, the PDF's pieces' pictures, and the room flow's lengths in the role's unit.
final class Founder29OctTests: XCTestCase {
    private let ws = Workshop()
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }
    private func doorWidths(_ m: Module) -> [Int] { m.sections.flatMap { frontSizes($0.fronts, frontW($0), m.h, ws).map(\.1) } }

    /* ---------------- the gorka bridge's doors ---------------- */

    func testTheBridgeGetsTheFewestDoorsOf600OrLess() {
        // 3000 wide with two 500 towers: a 2000 bridge, 3 doors of 663 were too heavy; 4 of 497 now
        XCTAssertEqual(gkBridgeDoors(2000, ws), 4)
        XCTAssertEqual(gkBridgeDoors(GK_NICHE_MIN, ws), 2)
        XCTAssertEqual(gkBridgeDoors(1500, ws), 3)
        let r = gorkaRoles(piece("gorka"))!
        let br = r.bridge!
        XCTAssertEqual(br.sections.count, 4)
        XCTAssertTrue(doorWidths(br).allSatisfy { $0 <= GK_DOOR_MAX }, "\(doorWidths(br))")
        XCTAssertFalse(wardrobeChecks(br, 3100, 2700, ws, [], []).contains { $0.key == "wc.doorWide" })
        // the base keeps its three drawers
        XCTAssertEqual(r.base!.sections.count, 3)
        // every width: no door over 600, and one door fewer would have one
        for nw in stride(from: GK_NICHE_MIN, through: 4000, by: 50) {
            let n = gkBridgeDoors(nw, ws)
            func widest(_ k: Int) -> Int {
                splitSections(nw, Array(repeating: Section(0, fronts: Fronts("door", 1)), count: k))
                    .flatMap { frontSizes($0.fronts, frontW($0), GK_BRIDGE_H, ws).map(\.1) }.max() ?? 0
            }
            XCTAssertLessThanOrEqual(widest(n), GK_DOOR_MAX, "\(nw)")
            if n > 2 { XCTAssertGreaterThan(widest(n - 1), GK_DOOR_MAX, "\(nw)") }
        }
        // a wider gorka (3600, 2600 bridge): five doors
        let wide = gorkaRoles(piece("gorka", ["w": 3600]))!.bridge!
        XCTAssertEqual(wide.sections.count, gkBridgeDoors(wide.w, ws))
        XCTAssertTrue(doorWidths(wide).allSatisfy { $0 <= GK_DOOR_MAX })
    }

    /* ---------------- a wall-hung piece's size and its height off the floor ---------------- */

    func testAWallHungPieceShowsItsBoxAndItsOwnFloorLine() {
        // a vanity on the wall: 800 × 550 × 450 box, 300 off the floor (its step height is floor to top, 850)
        let v = piece("sinkV", ["mt": 1])
        XCTAssertEqual(valsOf(v, ws)["h"], 850)
        XCTAssertEqual(shownVals(v, ws)["h"], 550)
        XCTAssertEqual(sizeLine(v, ws, "mm"), "800 × 550 × 450 mm")
        XCTAssertEqual(floorElev(v), 300)
        // standing on its legs: no line, its size as before
        let s = piece("sinkV")
        XCTAssertNil(floorElev(s))
        XCTAssertEqual(sizeLine(s, ws, "mm"), "800 × 850 × 450 mm")
        // a wall shelf and the mirror cabinet hang too
        XCTAssertEqual(floorElev(piece("shelfW")), 1500)
        XCTAssertEqual(floorElev(piece("mirrorC")), 1250)
        XCTAssertEqual(sizeLine(piece("mirrorC"), ws, "mm"), "600 × 700 × 150 mm")
        // the line's words
        XCTAssertEqual(Strings.t("fz.offFloor", .uz, ["v": 300, "u": "mm"]), "poldan 300 mm")
        XCTAssertEqual(Strings.t("fz.offFloor", .ru, ["v": 300, "u": "мм"]), "от пола 300 мм")
        // boxes on another box, or on the floor, are not lifted: a gorka's glass boxes and bridge; its floating base is
        let g = piece("gorka")
        let r = gorkaRoles(g)!
        XCTAssertNil(floorElev(g))
        XCTAssertNil(wallLift(r.ups[0], boxes(g)))
        XCTAssertNil(wallLift(r.bridge!, boxes(g)))
        XCTAssertNil(wallLift(r.lows[0], boxes(g)))
        XCTAssertEqual(wallLift(r.base!, boxes(g)), GK_BASE_ELEV)
    }

    func testTheDesignersFrontViewKeepsTheBoxsMillimetresWhenRaised() {
        // the 2D front view: the drawing reaches down to the floor, the box's own mm still count from its bottom
        let lay = KLay(1000, 300 + 1500, 360, true)
        let map = DzcMap(lay, CGSize(width: 390, height: 600), DzcCam(), top: 58, bottom: 6, lift: 1500)
        let flat = DzcMap(lay, CGSize(width: 390, height: 600), DzcCam(), top: 58, bottom: 6)
        XCTAssertEqual(map.sy(0), flat.sy(1500), accuracy: 0.001)
        XCTAssertEqual(map.sy(300), flat.sy(1800), accuracy: 0.001)
        for mm in [0, 120, 300] { XCTAssertLessThanOrEqual(abs(map.mmY(map.sy(mm)) - mm), 1, "\(mm)") }
        // below the box, over the floor, is below its 0
        XCTAssertLessThan(map.mmY(flat.sy(700)), 0)
    }

    /* ---------------- the PDF's pictures ---------------- */

    func testPiecesWithoutASavedViewGetTheirOwnPicture() {
        var room = Room(id: "r1", floorId: "", name: "Yotoqxona")
        var a = piece("sinkV"); a.id = "a"; a.roomId = "r1"
        var b = piece("shelfW"); b.id = "b"; b.roomId = nil
        var sn = Snap(name: "T")
        sn.furniture = [a, b]
        sn.rooms = [SnapRoom(room: room, floorLabel: "")]
        XCTAssertEqual(pdfShotPieces(sn).map(\.id), ["a", "b"])
        // the maker saved a view of the room: that view shows the piece, the room-less one still gets its own
        room.views = [View3D(id: "v", img: "views/v.jpg", ts: 0)]
        sn.rooms = [SnapRoom(room: room, floorLabel: "")]
        XCTAssertEqual(pdfShotPieces(sn).map(\.id), ["b"])
        XCTAssertEqual(pdfShotRoom(a, sn)?.id, "r1"); XCTAssertNil(pdfShotRoom(b, sn))
        // 3D views off in the PDF's parts: none
        sn.pdf.views = false
        XCTAssertTrue(pdfShotPieces(sn).isEmpty)
        // small pictures: about 560 × 420 px
        XCTAssertEqual(PDF_SHOT_SPEC.pxW, 560); XCTAssertEqual(PDF_SHOT_SPEC.pxH, 420)
        // a picture's key changes with the piece
        var b2 = b; b2.modules[0].w += 100
        XCTAssertNotEqual(PdfShots.shared.key(b, sn, .high), PdfShots.shared.key(b2, sn, .high))
        XCTAssertEqual(PdfShots.shared.key(b, sn, .high), PdfShots.shared.key(b, sn, .high))
    }

    /* ---------------- the room flow's unit ---------------- */

    func testRoomTextsTakeTheRolesUnit() {
        // millimetres (a furniture maker): nothing changes
        XCTAssertEqual(unitTemplate("Devor 300 mm dan kam bo‘lmaydi.", .mm, false, word: "mm"), "Devor 300 mm dan kam bo‘lmaydi.")
        // metres: fixed sizes turned, "mm" after a value's place the unit's word
        XCTAssertEqual(unitTemplate("Devor 300 mm dan kam bo‘lmaydi.", .m, false, word: "m"), "Devor 0,30 m dan kam bo‘lmaydi.")
        XCTAssertEqual(unitTemplate("Devor 999 999 mm gacha.", .m, false, word: "m"), "Devor 999,999 m gacha.")
        XCTAssertEqual(unitTemplate("300 – 999 999 mm oralig‘ida", .m, false, word: "m"), "0,30 – 999,999 m oralig‘ida")
        XCTAssertEqual(unitTemplate("От 300 до 999 999 мм", .m, false, word: "м"), "От 0,30 до 999,999 м")
        XCTAssertEqual(unitTemplate("300 to 999,999 mm", .m, true, word: "m"), "0.30 to 999.999 m")
        XCTAssertEqual(unitTemplate("{n}: uzunligi {a} → {b} mm", .m, false, word: "m"), "{n}: uzunligi {a} → {b} m")
        XCTAssertEqual(unitTemplate("Девор {w}: {a} → {b} мм", .m, false, word: "м"), "Девор {w}: {a} → {b} м")
        XCTAssertEqual(unitTemplate("{n} · {v} mm · standart 100", .m, false, word: "m"), "{n} · {v} m · standart 0,10")
        XCTAssertEqual(unitTemplate("Qalinlik 100 mm (80 / 100 / 120 / 250).", .m, false, word: "m"), "Qalinlik 0,10 m (0,08 / 0,10 / 0,12 / 0,25).")
        // centimetres
        XCTAssertEqual(unitTemplate("Devor 300 mm dan kam bo‘lmaydi.", .cm, false, word: "sm"), "Devor 30 sm dan kam bo‘lmaydi.")
        // words with "mm" inside them and texts without it stay
        XCTAssertEqual(unitTemplate("Kommunikatsiya", .m, false, word: "m"), "Kommunikatsiya")
        XCTAssertEqual(unitTemplate("{v}. To‘g‘ri bo‘lsa", .m, false, word: "m"), "{v}. To‘g‘ri bo‘lsa")
    }

    func testRoomLengthsAreTypedAndKeptInMillimetres() {
        // typed in the unit (decimals for m and cm), kept as mm
        XCTAssertEqual(rshParse("3,4", .m), 3400)
        XCTAssertEqual(rshParse("3.45", .m), 3450)
        XCTAssertEqual(rshParse("2,5", .cm), 25)
        XCTAssertEqual(rshParse("340", .cm), 3400)
        XCTAssertEqual(rshParse("3400", .mm), 3400)
        XCTAssertNil(rshParse("3,4567", .m))
        XCTAssertEqual(rshParse("0", .m, zeroOk: true), 0)
        // the limits in the unit: 300 mm, 999 999 mm and the 30 m note
        XCTAssertEqual(Geo.fmtLen(SHAPE_WALL_MIN, .m, false), "0,30")
        XCTAssertEqual(Geo.fmtLen(SHAPE_WALL_MAX, .m, false), "999,999")
        XCTAssertEqual(Geo.fmtLen(SHAPE_WALL_MIN, .cm, false), "30")
        XCTAssertEqual(rshParse(Geo.fmtField(SHAPE_WALL_MAX, .m, false), .m), SHAPE_WALL_MAX)
        XCTAssertEqual(rshParse(Geo.fmtField(SHAPE_WALL_MIN, .cm, false), .cm), SHAPE_WALL_MIN)
        XCTAssertTrue(reWallLenOk(rshParse("0,3", .m)!)); XCTAssertFalse(reWallLenOk(rshParse("0,29", .m)!))
        XCTAssertEqual(rshParse("30", .m), Geo.WALL_BIG)
    }

    /* ---------------- test mode ---------------- */

    func testTestModeHasItsOffTexts() {
        for k in ["lt.devOff", "lt.devOffDone", "lt.devOnRow", "fz.offFloor", "fd.lineWb", "re.bigDu"] {
            XCTAssertTrue(Strings.has(k), k)
            for l in Lang.allCases { XCTAssertFalse((Strings.template(k, l) ?? "").isEmpty, k) }
        }
        XCTAssertEqual(Strings.t("lt.devOff", .uz), "Test rejimini o‘chirish")
    }
}
