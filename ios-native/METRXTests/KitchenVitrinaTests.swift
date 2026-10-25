import XCTest
@testable import METRX

/// A kitchen's glass-door wall unit, the vitrina (Kitchen.swift glassDoors; the approved mockup's lit wall unit with
/// dishes): its glass doors bought by the m², not cut; the fluted glass only when the look has it; hinges and handles
/// as any door's, push latches when the handle type says so; an older kitchen saved as it was (Android
/// KitchenVitrinaTest, the same cases and numbers).
final class KitchenVitrinaTests: XCTestCase {
    private let ws = Workshop()

    private func vitrina(_ w: Int = 600) -> Module { var m = template("vitrina", ws, "A", w); m.id = "v"; m.x = 0; return m }
    private func kitchen(_ m: Module, look: PieceLook? = nil, handle: String = "") -> Furniture {
        Furniture(id: "k", kind: "kitchen", walls: ["A"], modules: [m], handle: handle, look: look)
    }
    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    /// Keys sorted: JSONEncoder's own key order is not fixed from one call to the next.
    private func encode<T: Encodable>(_ v: T) -> String {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        return String(decoding: try! e.encode(v), as: UTF8.self)
    }
    private func object(_ s: String) -> Any { try! JSONSerialization.jsonObject(with: Data(s.utf8)) }
    /// Android writes nulls (encodeDefaults); the iPhone leaves them out.
    private func noNulls(_ x: Any) -> Any {
        if let d = x as? [String: Any] {
            var o: [String: Any] = [:]
            for (k, v) in d where !(v is NSNull) { o[k] = noNulls(v) }
            return o
        }
        if let a = x as? [Any] { return a.map { noNulls($0) } }
        return x
    }
    private func canonical(_ x: Any) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: x, options: [.sortedKeys]), as: UTF8.self)
    }
    private func triples(_ ps: [FPart]) -> [[Int]] { ps.map { [$0.L, $0.W, $0.qty] } }

    func testAVitrinaIsAWallUnitWithGlassDoorsAndAGlassShelf() {
        let v = vitrina()
        XCTAssertEqual(v.type, "wall"); XCTAssertEqual(v.fronts, Fronts("door", 2))
        XCTAssertEqual([v.w, v.h, v.d, v.elev], [600, 720, 300, 1458])
        XCTAssertTrue(v.glass && glassDoors(v)); XCTAssertFalse(v.accentIn)
        XCTAssertEqual(v.inserts, [Insert("glass", qty: 1)])
        XCTAssertEqual(kindOf(v), "vitrina")
        XCTAssertTrue(LIB_UP.contains("vitrina"))
        // board doors again: board shelves, the wood accent inside goes with the glass
        var acc = v; acc.accentIn = true
        let board = withGlassDoors(acc, false)
        XCTAssertFalse(board.glass || board.accentIn || glassDoors(board))
        XCTAssertEqual(board.inserts, [Insert("shelf", qty: 1)])
        XCTAssertEqual(kindOf(board), "wall")
        // only a wall unit with doors takes glass
        XCTAssertFalse(withGlassDoors(template("open", ws, "A", 600), true).glass)
        XCTAssertFalse(withGlassDoors(template("base", ws, "A", 600), true).glass)
        var open = v; open.fronts = Fronts("open", 0)
        XCTAssertFalse(glassDoors(open))
    }

    func testNoFrontBoardIsCutForAGlassDoor() {
        let v = vitrina()
        let ps = partsOf(v, ws)
        XCTAssertTrue(ps.allSatisfy { $0.role != "front" })
        XCTAssertTrue(ps.allSatisfy { $0.key != "fp.door" && $0.key != "fp.shelf" })
        // the carcass is cut as usual: the same sides, top and bottom and back as the board wall unit's
        let bp = partsOf(withGlassDoors(v, false), ws)
        XCTAssertEqual(bp.filter { $0.role != "front" && $0.key != "fp.shelf" }, ps)
        XCTAssertEqual(triples(bp.filter { $0.key == "fp.door" }), [[717, 297, 2]])
        XCTAssertEqual(triples(ps), [[720, 300, 2], [568, 300, 2], [716, 596, 1]])
        // nor in the cut list of the kitchen
        XCTAssertTrue(cutList([kitchen(v)], ws).allSatisfy { $0.p.role != "front" })
    }

    func testTheGlassIsBoughtByTheSquareMetre() {
        let v = vitrina()
        let hw = hardwareOf(v, ws)
        // two doors 717 × 297 in their frames; one glass shelf 564 × 275
        XCTAssertEqual(hw["glassDoor"], 2 * 717 * 297); XCTAssertEqual(hw["glassDoor"], 425898)
        XCTAssertEqual(hw["glassShelf"], 155100); XCTAssertEqual(hw["pin"], 4)
        // hinges and handles as any door's
        XCTAssertEqual(hw["hingeSoft"], 4); XCTAssertEqual(hw["handle"], 2); XCTAssertNil(hw["push"])
        XCTAssertEqual(hw["hanger"], 2); XCTAssertEqual(hw["confirmat"], 16)
        let f = kitchen(v)
        let gl = line(f, "glassDoor")
        XCTAssertEqual(gl?.qty ?? 0, 0.43, accuracy: 1e-9); XCTAssertEqual(gl?.price, 900000); XCTAssertEqual(gl?.amount, 387000)
        XCTAssertEqual(line(f, "glassShelf")?.amount, 48000)
        // a board wall unit has none
        XCTAssertNil(hardwareOf(withGlassDoors(v, false), ws)["glassDoor"])
    }

    func testTheFlutedGlassIsPricedOnlyWhenOn() {
        let v = vitrina()
        let plain = kitchen(v, look: PieceLook())
        let fluted = kitchen(v, look: PieceLook(fglass: true))
        XCTAssertNil(hardware([plain], ws)["fglass"]); XCTAssertNil(line(plain, "fglass"))
        XCTAssertEqual(hardware([fluted], ws)["fglass"], 425898)
        let fl = line(fluted, "fglass")
        XCTAssertEqual(fl?.qty ?? 0, 0.43, accuracy: 1e-9); XCTAssertEqual(fl?.amount, 193500)
        // the glass itself is the same either way; a board wall unit takes no fluted glass
        XCTAssertEqual(line(plain, "glassDoor")?.amount, line(fluted, "glassDoor")?.amount)
        XCTAssertNil(hardware([kitchen(withGlassDoors(v, false), look: PieceLook(fglass: true))], ws)["fglass"])
    }

    func testPushLatchesWhenTheHandleTypeSaysSo() {
        let v = vitrina()
        // a Gola kitchen's wall units open by a push latch
        let gola = hardware([kitchen(v, handle: GOLA)], ws)
        XCTAssertEqual(gola["push"], 2); XCTAssertNil(gola["handle"]); XCTAssertEqual(gola["hingeSoft"], 4)
        // without handles ("Tutqichsiz")
        let bare = hardwareOf(allHandles(v, false), ws)
        XCTAssertEqual(bare["push"], 2); XCTAssertNil(bare["handle"])
    }

    func testAnOlderKitchenSavesAsItWas() throws {
        let old = #"{"id":"f1","kind":"kitchen","name":"Oshxona 1","roomId":null,"walls":["A"],"modules":[{"id":"m1","type":"wall","w":600,"h":720,"d":300,"x":0,"wall":"A","elev":1458,"# +
            #""fronts":{"kind":"door","n":2},"inserts":[{"kind":"shelf","pos":0,"qty":2,"h":0}],"sections":[],"legs":false,"soft":true,"handles":true,"label":"","app":"","sideL":true,"sideR":true,"slide":null,"base":null,"led":false,"opt":null}],"# +
            #""mats":{"carcass":"ldsp16w","front":"ldsp16k","back":"hdf3"},"created":0,"layout":"I","ws":"","free":null,"model":"","keep":false,"# +
            #""kx":null,"type":"","pose":null,"baseH":null,"hand":"","handle":""}"#
        let f = try JSONDecoder().decode(Furniture.self, from: Data(old.utf8))
        XCTAssertEqual(f.modules.count, 1)
        let m = f.modules[0]
        XCTAssertFalse(m.glass || m.accentIn || glassDoors(m))
        // saved again: Android's fields and values (its nulls left out, as the iPhone always has), none of the new ones
        let out = encode(f)
        XCTAssertEqual(canonical(object(out)), canonical(noNulls(object(old))))
        XCTAssertFalse(out.contains("glass") || out.contains("accentIn"))
        // a vitrina writes its flags, and reads them back
        var gm = withGlassDoors(m, true); gm.accentIn = true
        var g = f; g.modules = [gm]
        let out2 = encode(g)
        XCTAssertTrue(out2.contains(#""glass":true"#) && out2.contains(#""accentIn":true"#))
        XCTAssertTrue(out2.contains(#"{"h":0,"kind":"glass","pos":0,"qty":2}"#))
        XCTAssertEqual(try JSONDecoder().decode(Furniture.self, from: Data(out2.utf8)), g)
        // glass without the accent: only the glass flag is written
        XCTAssertFalse(encode(withGlassDoors(m, true)).contains("accentIn"))
    }

    func testTheDishesStandOnTheFloorAndTheGlassShelf() {
        let v = vitrina()
        // the shelf halfway up, as a board shelf is; three plates (three turned squares each) and four cups
        XCTAssertEqual(vitrinaShelves(v, ws.t), [1810])
        let d = vitrinaDishes(v, ws.t)
        XCTAssertEqual(d.count, 13)
        XCTAssertEqual(d.filter { $0.y0 < 1810 }.count, 9); XCTAssertEqual(d.filter { $0.y0 >= 1816 }.count, 4)
        // a narrow one: one plate and one cup
        XCTAssertEqual(vitrinaDishes(vitrina(300), ws.t).count, 4)
        // without a shelf: plates only
        var bare = v; bare.inserts = []
        XCTAssertEqual(vitrinaDishes(bare, ws.t).count, 9)
    }
}
