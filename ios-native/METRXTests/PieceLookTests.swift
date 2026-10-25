import XCTest
@testable import METRX

/// The design data, presets, options and their prices (modern 3D part 2, 25 Oct 2026; Core/PieceLook.swift,
/// Core/DecorPresets.swift; Android LookTest, the same cases and numbers).
final class PieceLookTests: XCTestCase {
    private let ws = Workshop()

    private func kitchen(_ layout: String = "I", _ sides: [Int] = [3000], island: Int = 0) -> Furniture {
        var f = newFreeKitchen("Oshxona 1", layout, layout, sides, island, 2700, ws)
        f.id = "k"
        return f
    }

    private func mod(_ kind: String, _ id: String, _ x: Int) -> Module { var m = template(kind, ws, "A", 600); m.id = id; m.x = x; return m }

    /// A kitchen of one base unit with doors, a drawer unit, a wall unit and a tall pantry.
    private func units() -> Furniture {
        Furniture(id: "u", kind: "kitchen", walls: ["A"], modules: [mod("base", "b", 0), mod("drawers", "d", 600), mod("wall", "w", 0), mod("pantry", "t", 1200)])
    }

    private func bed() -> Furniture {
        Furniture(id: "b", kind: "wardrobe", modules: [Module(id: "bm", type: "bed", w: 1700, h: 450, d: 2100, opt: ItemOpt(bed: "legs", hb: 1100))], type: "bed")
    }

    private func kupe3() -> Furniture {
        var k = newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws)
        k.id = "s"
        return k
    }

    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }
    private func dec(_ s: String) -> Decimal { Decimal(string: s)! }
    private func halfUp(_ x: Decimal) -> Decimal { var a = x, r = Decimal(); NSDecimalRound(&r, &a, 0, .plain); return r }

    /* ---------------- JSON ---------------- */

    /// Keys sorted: JSONEncoder's own key order is not fixed from one call to the next (the app's fingerprint sorts too).
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
    /// The same JSON, keys sorted, written by one serializer: two of them equal byte for byte when their content is.
    private func canonical(_ x: Any) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: x, options: [.sortedKeys]), as: UTF8.self)
    }

    /* ---------------- older orders ---------------- */

    func testAnOlderOrderLoadsAndSavesByteForByte() throws {
        let old = #"{"id":"f1","kind":"kitchen","name":"Oshxona 1","roomId":null,"walls":[],"modules":[{"id":"m1","type":"base","w":600,"h":720,"d":560,"x":0,"wall":null,"elev":0,"# +
            #""fronts":{"kind":"door","n":2},"inserts":[],"sections":[],"legs":true,"soft":true,"handles":true,"label":"","app":"","sideL":true,"sideR":true,"slide":null,"base":null,"led":false,"opt":null}],"# +
            #""mats":{"carcass":"ldsp16w","front":"ldsp16k","back":"hdf3"},"created":0,"layout":"I","ws":"","free":null,"model":"","keep":false,"# +
            #""kx":{"joint":"butt","cutouts":true,"splash":600,"plinth":false,"cornice":false,"led":false,"ends":0,"endsUp":0},"type":"","pose":null,"baseH":null,"hand":"","handle":""}"#
        let f = try JSONDecoder().decode(Furniture.self, from: Data(old.utf8))
        XCTAssertNil(f.look); XCTAssertNil(f.mats.frontUp); XCTAssertNil(f.mats.top); XCTAssertNil(f.mats.splash)
        // saved again: Android's fields and values (its nulls left out, as the iPhone always has), and none of the new ones
        let out = encode(f)
        XCTAssertEqual(canonical(object(out)), canonical(noNulls(object(old))))
        XCTAssertEqual(encode(try JSONDecoder().decode(Furniture.self, from: Data(out.utf8))), out)
        for k in ["look", "frontUp", "\"top\"", "\"splash\":\"", "finish", "\"per\"", "\"tex\""] { XCTAssertFalse(out.contains(k), k) }
        // the workshop's older boards are saved as before (an issued quote's materials stay as they were)
        let board = ##"{"id":"ldsp16w","kind":"board","name":"LDSP 16 · Oq","t":16,"l":2800,"w":2070,"price":"620000","grain":false,"rgb":"#F5F5F2","preset":true}"##
        XCTAssertEqual(canonical(object(encode(MAT_PRESETS.first { $0.id == "ldsp16w" }!))), canonical(object(board)))
        XCTAssertEqual(MAT_PRESETS.prefix(10).map(\.id), ["ldsp16w", "ldsp16k", "ldsp18a", "mdf18", "ldsp16mr", "hdf3", "wt38", "splash6", "band2", "band04"])
        XCTAssertTrue(MAT_PRESETS.prefix(10).allSatisfy { $0.finish.isEmpty && $0.tex == nil && !$0.byArea })
        // an order without a style saves as before
        var p = Project(id: "p", name: "A")
        p.industry = "furniture"
        XCTAssertFalse(encode(p).contains("fstyle"))
        p.fstyle = "gola"
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: Data(encode(p).utf8)).fstyle, "gola")
        // a new piece's look, upper fronts, worktop and backsplash are saved and read back
        let g = withPreset(f, "twotone")
        let gs = encode(g)
        XCTAssertTrue(gs.contains("\"look\"") && gs.contains("\"frontUp\":\"ag_white\""))
        XCTAssertEqual(try JSONDecoder().decode(Furniture.self, from: Data(gs.utf8)), g)
        // a look writes only what is not its default, as Android's
        XCTAssertEqual(encode(PieceLook()), "{}")
        XCTAssertEqual(canonical(object(encode(PieceLook(preset: "gola", style: "flat", legs: true)))), canonical(object(#"{"preset":"gola","legs":true}"#)))
        XCTAssertEqual(try JSONDecoder().decode(PieceLook.self, from: Data("{}".utf8)), PieceLook())
    }

    func testAnOlderOrderCostsAndLooksAsBefore() {
        var k = kitchen(); k.kx = KExtras(splash: 600, plinth: true)
        XCTAssertNil(k.look)
        let c = cost(k)
        // the usual worktop and backsplash by the metre, the boards by the sheet, nothing of the design
        XCTAssertEqual(c.lines.filter { $0.key == "wt38" }.map(\.unit), ["m"])
        let sp = c.lines.filter { $0.key == "splash6" }
        XCTAssertEqual(sp.count, 1)
        XCTAssertEqual(sp[0].qty, Double(splashMm(k)) / 1000, accuracy: 1e-9)
        XCTAssertEqual(sp[0].unit, "m")
        XCTAssertTrue(c.lines.filter { $0.group == "mat" && ["ldsp16w", "ldsp16k", "hdf3"].contains($0.key) }.allSatisfy { $0.unit == "sheet" })
        let design: Set<String> = ["gola", "frontShaker", "frontFluted", "legMetal", "ceilUnit", "fglass", "waterfall", "mirrorBronze", "mirrorGraphite",
                                   "ledSensor", "headSoft", "headTufted", "softPanel", "handle640", "handle1024"]
        XCTAssertTrue(c.lines.allSatisfy { !design.contains($0.key) })
        XCTAssertTrue(lookHardware(k, ws).pairs.isEmpty)
        // the 3D gets the colours it had: flat, matte, no texture, grey handles
        let m = k.modules.first { !isUpper($0) && $0.type == "base" }!
        XCTAssertEqual(lookOf(k, m, "front"), Surface("#CDBFAE", "matte", nil, true, "ldsp16k", "flat"))
        XCTAssertEqual(lookOf(k, m, "worktop").rgb, "#4B4F58")
        XCTAssertEqual(lookOf(k, m, "handle").rgb, "#4B5563")
        XCTAssertEqual(lookOf(k, nil, "splash").rgb, "#E8E2D8")
        // the same piece, its front changed to an older board, still costs by the sheet
        var mdf = k; mdf.mats.front = "mdf18"
        XCTAssertEqual(cost(mdf).lines.filter { $0.key == "mdf18" }.map(\.unit), ["sheet"])
    }

    /* ---------------- the presets ---------------- */

    func testExactlyTheSixApprovedPresets() {
        XCTAssertEqual(DESIGN_PRESETS.map(\.id), ["twotone", "gloss", "gola", "neo", "wood", "dark"])
        let ids = Set(MAT_PRESETS.map(\.id))
        for p in DESIGN_PRESETS {
            let g = withPreset(kitchen(), p.id)
            for id in [g.mats.front, g.mats.frontUp, g.mats.top, g.mats.splash, g.look!.accent].compactMap({ $0 }) { XCTAssertTrue(ids.contains(id), p.id + " " + id) }
            XCTAssertEqual(presetOf(g), p.id)
            XCTAssertEqual(g.kx!.splash, 600)
            XCTAssertFalse(g.look!.legs || g.look!.fglass || g.look!.waterfall)
        }
    }

    private struct Want: Equatable {
        let front: String, up: String?, top: String, splash: String, handle: String, hcol: String, style: String
        let finish: String, crown: String, accent: String, mirror: String, fabric: String, head: String
    }
    private func want(_ front: String, _ up: String?, _ top: String, _ splash: String, _ handle: String, _ hcol: String, _ style: String,
                      _ finish: String, _ crown: String, _ accent: String, _ mirror: String, _ fabric: String, _ head: String) -> Want {
        Want(front: front, up: up, top: top, splash: splash, handle: handle, hcol: hcol, style: style, finish: finish, crown: crown, accent: accent,
             mirror: mirror, fabric: fabric, head: head)
    }

    func testEachPresetsFields() {
        let wants: [(String, Want)] = [
            ("twotone", want("ag_graphite", "ag_white", "wt38m", "skGlass", "", "black", "flat", "gloss", "", "wd_walnut", "graphite", "olive", "vertical")),
            ("gloss", want("ag_white", nil, "wt38m", "skPrint", LONG_V, "chrome", "flat", "gloss", "", "wd_halifax", "silver", "grey", "panels")),
            ("gola", want("sm_cashmere", nil, "wt38c", "spTile", GOLA, "black", "flat", "matte", "", "wd_craft", "bronze", "mocha", "vertical")),
            ("neo", want("en_ivory", nil, "wt38o", "spTile", "handleKnob", "gold", "shaker", "matte", "cornice", "wd_walnut", "bronze", "cream", "tufted")),
            ("wood", want("wd_halifax", "sm_white", "wt38m", "spTile", "", "black", "flat", "matte", "", "wd_halifax", "silver", "cream", "panels")),
            ("dark", want("sm_black", "sm_graphite", "wt38d", "skGlass", LONG_V, "brass", "flat", "matte", "ceiling", "wd_walnut", "bronze", "navy", "vertical"))
        ]
        for (id, w) in wants {
            let g = withPreset(kitchen(), id)
            let l = g.look!
            XCTAssertEqual(want(g.mats.front, g.mats.frontUp, g.mats.top!, g.mats.splash!, g.handle, l.hcol, l.style, l.finish, crownOf(g), l.accent, l.mirror, l.fabric, l.head), w, id)
        }
        // the cornice is the kitchen's extra; to the ceiling is the look's
        XCTAssertTrue(withPreset(kitchen(), "neo").kx!.cornice)
        XCTAssertEqual(withPreset(kitchen(), "dark").look!.crown, "ceiling")
        XCTAssertFalse(withPreset(kitchen(), "dark").kx!.cornice)
        // a two-tone kitchen's wall units take the upper board, in the cut list and in the 3D
        let t = withPreset(kitchen(), "twotone")
        let wall = t.modules.first { isUpper($0) }!, low = t.modules.first { $0.type == "base" }!
        XCTAssertEqual(lookOf(t, wall, "front").mat, "ag_white"); XCTAssertEqual(lookOf(t, low, "front").mat, "ag_graphite")
        XCTAssertEqual(lookOf(t, wall, "front").finish, "gloss")
        let rows = cutList([t], ws)
        XCTAssertTrue(rows.contains { $0.p.key == "fp.door" && $0.mat == "ag_white" }); XCTAssertTrue(rows.contains { $0.p.key == "fp.door" && $0.mat == "ag_graphite" })
        // neoclassic: enamel MDF, milled, the finish the look's; wood: a grained wood decor with its texture
        XCTAssertEqual(lookOf(withPreset(kitchen(), "neo"), low, "front"), Surface("#EEE5D2", "matte", nil, false, "en_ivory", "shaker"))
        let wd = lookOf(withPreset(kitchen(), "wood"), low, "front")
        XCTAssertEqual(wd.tex, "oak_light"); XCTAssertEqual(wd.finish, "wood"); XCTAssertTrue(wd.grain)
        XCTAssertEqual(lookOf(t, nil, "worktop").tex, "marble_white")
        XCTAssertEqual(lookOf(withPreset(kitchen(), "dark"), nil, "worktop").tex, "stone_dark")
        XCTAssertEqual(lookOf(withPreset(kitchen(), "dark"), nil, "handle").rgb, HANDLE_RGB["brass"])
    }

    func testPresetsOnOtherPieces() {
        // a kupe: the fronts, the tint; a new one gets the mirror on its middle door
        let kupe = kupe3()
        XCTAssertEqual(kupe.modules[0].slide!.n, 3)
        let k = withPreset(kupe, "twotone", fresh: true)
        XCTAssertEqual(k.mats.front, "ag_graphite"); XCTAssertEqual(k.mats.frontUp, "ag_white")
        XCTAssertEqual(k.modules[0].slide!.panels, ["ldsp", "mirror", "ldsp"])
        XCTAssertEqual(middleFill(k), "mirror"); XCTAssertEqual(lookOf(k, nil, "mirror").rgb, MIRROR_RGB["graphite"])
        // not a kitchen: no worktop or backsplash, no crown; changing the style later leaves the doors
        XCTAssertNil(k.mats.top); XCTAssertNil(k.mats.splash); XCTAssertEqual(k.look!.crown, "")
        var plain = k
        plain.modules = k.modules.map { m in var x = m; x.slide = Slide(m.slide!.n, ["ldsp", "ldsp", "ldsp"]); return x }
        XCTAssertEqual(withPreset(plain, "gloss").modules[0].slide!.panels, ["ldsp", "ldsp", "ldsp"])
        XCTAssertEqual(withPreset(k, "gloss").look!.mirror, "silver")
        // a hinged wardrobe with the Gola preset opens by push latches (Gola is a kitchen's)
        var ward = newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws)
        ward.id = "h"
        let gw = withPreset(ward, "gola")
        XCTAssertEqual(handleType(gw), "push"); XCTAssertFalse(hasHandles(gw))
        XCTAssertEqual(handleType(withPreset(kitchen(), "gola")), "gola")
        // a bed: fabric and headboard
        let gb = withPreset(bed(), "neo")
        XCTAssertEqual(gb.look!.head, "tufted"); XCTAssertEqual(gb.look!.fabric, "cream")
        XCTAssertEqual(lookOf(gb, nil, "fabric").tex, "boucle")
        XCTAssertEqual(lookOf(withPreset(bed(), "dark"), nil, "fabric").finish, "velvet")
    }

    /* ---------------- boards and options ---------------- */

    func testBoardsFollowTheFinishAndTheStyle() {
        XCTAssertEqual(boardFor("white", "gloss", "flat"), "ag_white")
        XCTAssertEqual(boardFor("white", "matte", "flat"), "sm_white")
        XCTAssertEqual(boardFor("white", "gloss", "shaker"), "en_white")
        XCTAssertEqual(boardFor("olive", "matte", "fluted"), "en_olive")
        XCTAssertEqual(boardFor("walnut", "gloss", "shaker"), "wd_walnut")
        XCTAssertEqual(colourOf("sm_navy"), "navy"); XCTAssertEqual(colourOf("wd_craft"), "craft"); XCTAssertNil(colourOf("ldsp16k")); XCTAssertNil(colourOf("ag_purple"))
        XCTAssertEqual(refinish("sm_cream", "gloss", "flat"), "ag_cream"); XCTAssertEqual(refinish("ldsp16k", "gloss", "flat"), "ldsp16k")
        XCTAssertEqual(worktopFor("stone", "onyx"), "wt38o"); XCTAssertEqual(worktopFor("slim", "dark"), "wt20d"); XCTAssertEqual(worktopFor("wood", "halifax"), "wt38h")
        XCTAssertEqual(worktopKind("wt20m"), "slim"); XCTAssertEqual(worktopKind(nil), "plain"); XCTAssertEqual(worktopDecor("wt38o"), "onyx")
        XCTAssertEqual(splashFor("print"), "skPrint"); XCTAssertNil(splashFor("")); XCTAssertEqual(splashKind("spTile"), "tile")
        // 27 colour fronts by the m², 6 woods, 8 worktops, 3 backsplashes; every one with a texture or none
        XCTAssertEqual(DECOR_PRESETS.count, 44)
        XCTAssertTrue(DECOR_PRESETS.filter { $0.kind == "board" }.allSatisfy { $0.byArea && !$0.finish.isEmpty })
        XCTAssertTrue(DECOR_PRESETS.compactMap(\.tex).allSatisfy { TEX_IDS.contains($0) })
        XCTAssertEqual(MAT_PRESETS.count, Set(MAT_PRESETS.map(\.id)).count)
        XCTAssertEqual(HW_PRESETS.count, Set(HW_PRESETS.map(\.id)).count)
        // an enamel board shows the look's finish
        var k = kitchen(); k.mats.front = "en_white"; k.look = PieceLook(finish: "gloss")
        XCTAssertEqual(lookOf(k, k.modules.first, "front").finish, "gloss")
    }

    func testCrownLegsWaterfallAndTheMiddleDoor() {
        let k = kitchen()
        XCTAssertEqual(crownOf(withCrown(k, "cornice")), "cornice"); XCTAssertTrue(withCrown(k, "cornice").kx!.cornice)
        XCTAssertEqual(crownOf(withCrown(withCrown(k, "cornice"), "ceiling")), "ceiling"); XCTAssertFalse(withCrown(withCrown(k, "cornice"), "ceiling").kx!.cornice)
        XCTAssertEqual(crownOf(withCrown(withCrown(k, "ceiling"), "")), "")
        XCTAssertTrue(metalLegs(look(k) { $0.legs = true })); XCTAssertEqual(look(withPreset(k, "gola")) { $0.legs = true }.look!.preset, "")
        XCTAssertEqual(waterfallEnds(look(k) { $0.waterfall = true }), 0)
        let o = kitchen("O", island: 1800)
        XCTAssertEqual(waterfallEnds(look(o) { $0.waterfall = true }), 2)
        XCTAssertEqual(waterfallEnds(look(kitchen("P", island: 1600)) { $0.waterfall = true }), 1)
        let kupe = newFreeWardrobe("Kupe", "s2", 1800, 2500, 600, true, "slide", ws, n: 2)
        XCTAssertEqual(withMiddleFill(kupe, "glass").modules[0].slide!.panels, ["ldsp", "glass"])
        XCTAssertEqual(middleDoors(4), [1, 2])
    }

    /* ---------------- prices (Advanced) ---------------- */

    func testDecorBoardsAreBoughtByTheSquareMetre() {
        var k = kitchen(); k.mats.front = "ag_white"
        let l = line(k, "ag_white")!
        XCTAssertEqual(l.unit, "m2"); XCTAssertEqual(l.price, 400000)
        let mm2 = cutList([k], ws).filter { $0.mat == "ag_white" }.reduce(0) { $0 + $1.p.L * $1.p.W * $1.p.qty }
        XCTAssertEqual(l.qty, (Double(mm2) / 10000).rounded(.up) / 100, accuracy: 1e-9)
        XCTAssertEqual(l.amount, halfUp(Decimal(400000) * dec(String(format: "%.2f", l.qty))))
        // two-tone: each board its own line
        let t = withPreset(kitchen(), "twotone")
        XCTAssertEqual(line(t, "ag_white")?.unit, "m2"); XCTAssertEqual(line(t, "ag_graphite")?.unit, "m2")
    }

    func testWorktopsAndBacksplashes() {
        var k = kitchen(); k.kx = KExtras(splash: 600)
        let run = worktopRuns(k).values.reduce(0, +)
        for (id, p) in [("wt38m", "420000"), ("wt38c", "400000"), ("wt20m", "2150000")] {
            var g = k; g.mats.top = id
            let l = line(g, id)!
            XCTAssertEqual(l.unit, "m"); XCTAssertEqual(l.qty, Double(run) / 1000, accuracy: 1e-9); XCTAssertEqual(l.price, dec(p))
            XCTAssertNil(line(g, "wt38"))
        }
        // skinali, printed skinali and tile by the area: the backsplash's length × its height
        for (id, p) in [("skGlass", "380000"), ("skPrint", "480000"), ("spTile", "230000")] {
            var g = k; g.mats.splash = id
            let l = line(g, id)!
            XCTAssertEqual(l.unit, "m2"); XCTAssertEqual(l.qty, (Double(splashMm(k) * 600) / 10000).rounded(.up) / 100, accuracy: 1e-9); XCTAssertEqual(l.price, dec(p))
            XCTAssertNil(line(g, "splash6"))
        }
        // two kitchens with different worktops: a line each
        var a = k; a.id = "a"; a.mats.top = "wt38m"
        var b = k; b.id = "b"
        let two = costOf([a, b], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(Set(two.lines.filter { $0.group == "mat" && $0.key.hasPrefix("wt") }.map(\.key)), ["wt38m", "wt38"])
    }

    func testGolaLongHandlesAndKnobs() {
        let u = units()
        let usual = hardware([u], ws)["handle"]!
        func fronts(_ id: String) -> Int { u.modules.first { $0.id == id }!.fronts.n }
        // Gola: the base and tall units' handles become the profile, the wall unit's a push latch
        let g = withHandleType(u, "gola")
        let hw = hardware([g], ws)
        XCTAssertNil(hw["handle"])
        let drawers = fronts("d")
        XCTAssertEqual(hw["gola"], 600 * 1 + 600 * drawers + 600 * 2)
        XCTAssertEqual(hw["push"], (hardware([u], ws)["push"] ?? 0) + fronts("w"))
        XCTAssertEqual(line(g, "gola")?.amount, Decimal(150000) * Decimal(Int((Double(hw["gola"]!) / 1000).rounded(.up))))
        XCTAssertEqual(line(g, "gola")?.unit, "m")
        // long verticals: 1024 on the pantry's tall doors, 640 on the 717 mm doors, 320 on the drawers
        let lv = withHandleType(u, "long")
        XCTAssertEqual(lv.handle, LONG_V)
        let ids = longHandleIds(lv, ws)
        XCTAssertEqual(ids.count, usual)
        let tallDoors = fronts("t")
        XCTAssertEqual(ids.filter { $0 == "handle1024" }.count, tallDoors)
        XCTAssertEqual(ids.filter { $0 == "handle640" }.count, 2 + fronts("w"))
        XCTAssertEqual(ids.filter { $0 == "handleLong" }.count, drawers)
        let c = cost(lv)
        XCTAssertEqual(c.lines.filter { $0.key == "handle1024" }.map(\.qty), [Double(tallDoors)])
        XCTAssertEqual(c.lines.filter { $0.key == "handle640" }.map(\.amount), [Decimal(85000) * Decimal(ids.filter { $0 == "handle640" }.count)])
        XCTAssertTrue(c.lines.filter { $0.key == "handle" }.isEmpty)
        // knobs at the knob's price (Change for all, as before)
        XCTAssertEqual(cost(withHandleType(u, "knob")).lines.filter { $0.key == "handleKnob" }.map(\.qty), [Double(usual)])
        // push: no handles at all
        XCTAssertNil(hardware([withHandleType(u, "push")], ws)["handle"])
    }

    func testFrontStylesLegsCeilingAndWaterfall() {
        let k = kitchen()
        let styled: Set<String> = ["fp.door", "fp.dFace", "fp.panel"]
        let doorsMm2 = k.modules.reduce(0) { a, m in a + partsOf(m, ws).filter { $0.role == "front" && styled.contains($0.key) }.reduce(0) { $0 + $1.L * $1.W * $1.qty } }
        let sh = line(look(k) { $0.style = "shaker" }, "frontShaker")!
        XCTAssertEqual(sh.unit, "m2"); XCTAssertEqual(sh.qty, (Double(doorsMm2) / 10000).rounded(.up) / 100, accuracy: 1e-9); XCTAssertEqual(sh.price, 100000)
        XCTAssertEqual(line(look(k) { $0.style = "fluted" }, "frontFluted")?.price, 250000)
        XCTAssertNil(line(look(k) { $0.style = "fluted" }, "frontShaker"))
        // metal legs: the legs priced as metal ones, no plinth
        var withPlinth = k; var x = k.kx ?? KExtras(); x.plinth = true; withPlinth.kx = x
        let legs = hardware([withPlinth], ws)["leg"]!
        let ml = look(withPlinth) { $0.legs = true }
        XCTAssertEqual(line(ml, "legMetal")?.qty, Double(legs)); XCTAssertEqual(line(ml, "legMetal")?.amount, Decimal(45000) * Decimal(legs))
        XCTAssertNil(line(ml, "leg")); XCTAssertNil(line(ml, "plinthK")); XCTAssertNotNil(line(withPlinth, "plinthK"))
        // a row of units to the ceiling by the metre of the wall units; the cornice and LED as before
        let ceil = line(withCrown(k, "ceiling"), "ceilUnit")!
        XCTAssertEqual(ceil.qty, (Double(wallUnitsMm(k)) / 1000 - 1e-9).rounded(.up)); XCTAssertEqual(ceil.price, 800000)
        XCTAssertNotNil(line(withCrown(k, "cornice"), "cornice"))
        var led = k; var lx = k.kx ?? KExtras(); lx.led = true; led.kx = lx
        XCTAssertTrue(line(led, "led") != nil && line(led, "ledPsu") != nil)
        // the waterfall ends of an island
        let o = look(kitchen("O", island: 1800)) { $0.waterfall = true }
        XCTAssertEqual(line(o, "waterfall")?.qty, 2.0); XCTAssertEqual(line(o, "waterfall")?.amount, 2400000)
    }

    func testMirrorsGlassLedAndBeds() {
        // a kupe's mirror door in bronze; lacobel stays the glass item
        let kupe = withMiddleFill(kupe3(), "mirror")
        let mirror = hardware([kupe], ws)["mirror"]!
        let br = look(kupe) { $0.mirror = "bronze" }
        XCTAssertEqual(hardware([br], ws)["mirrorBronze"], mirror); XCTAssertNil(hardware([br], ws)["mirror"])
        XCTAssertEqual(line(br, "mirrorBronze")?.price, 350000)
        XCTAssertNotNil(line(look(kupe) { $0.mirror = "graphite" }, "mirrorGraphite"))
        XCTAssertNotNil(line(withMiddleFill(kupe, "glass"), "glass"))
        // the inside LED with a door sensor a sliding door
        let lit = look(kupe) { $0.led = true }
        let hw = hardware([lit], ws)
        XCTAssertEqual(hw["led"], kupe.modules[0].w - 2 * ws.t); XCTAssertEqual(hw["ledPsu"], 1); XCTAssertEqual(hw["ledSensor"], 3)
        XCTAssertEqual(line(lit, "ledSensor")?.amount, 180000)
        // fluted glass over a vitrina's glass doors
        let vit = Furniture(id: "v", kind: "wardrobe", modules: [Module(id: "vm", type: "wardrobe", w: 900, h: 2000, d: 400, sections: [Section(900, fronts: Fronts("door", 2), face: "glass")])])
        let glass = hardware([vit], ws)["glassDoor"]!
        let fg = look(vit) { $0.fglass = true }
        XCTAssertEqual(hardware([fg], ws)["fglass"], glass); XCTAssertEqual(lookOf(fg, nil, "glass").tex, "fluted_glass")
        XCTAssertEqual(line(fg, "fglass")?.price, 450000)
        // a bed's upholstered headboard above the frame, tufted dearer, and the soft wall panel
        let soft = look(bed()) { $0.head = "vertical" }
        XCTAssertEqual(hardware([soft], ws)["headSoft"], 1700 * (1100 - 450))
        XCTAssertEqual(line(soft, "headSoft")!.qty, 1.11, accuracy: 1e-9); XCTAssertEqual(line(soft, "headSoft")?.amount, 999000)
        XCTAssertEqual(line(look(bed()) { $0.head = "tufted" }, "headTufted")?.price, 1300000)
        XCTAssertNil(line(look(bed()) { $0.head = "tufted" }, "headSoft"))
        let pan = line(look(bed()) { $0.panel = true }, "softPanel")!
        XCTAssertEqual(pan.qty, (Double((1700 + 800) * 1300) / 10000).rounded(.up) / 100, accuracy: 1e-9)
        XCTAssertNil(line(bed(), "headSoft")); XCTAssertNil(line(bed(), "softPanel"))
    }

    func testTheQuoteNamesTheNewMaterialsAndHandles() {
        var p = Project(id: "p", name: "A")
        p.industry = "furniture"; p.furniture = [withPreset(kitchen(), "gola")]
        let sn = furnSnap(snapshotOf(p), p, ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(Set(sn.fmats.map(\.id)), ["ldsp16w", "sm_cashmere", "hdf3", "wt38c", "spTile"])
        XCTAssertEqual(sn.fhandles, "Gola profili (metr)")
        // an older order: the usual materials and handle, as before (the iPhone's older quotes name no backsplash board;
        // Android's name splash6 too)
        var old = Project(id: "q", name: "B")
        var k = kitchen(); k.kx = KExtras(splash: 600)
        old.industry = "furniture"; old.furniture = [k]
        let so = furnSnap(snapshotOf(old), old, ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(so.fmats.map(\.id), ["ldsp16w", "ldsp16k", "hdf3", "wt38"])
        XCTAssertEqual(so.fhandles, "Tutqich skoba 128")
    }
}
