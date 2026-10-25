import XCTest
import UIKit
@testable import METRX

/// The modern kitchen in 3D ("modern furniture 3D" part 3, 25 Oct 2026; Geo/Kitchen3D.swift): where handles go and how
/// long they are, the Gola profile, the cornice and the row to the ceiling, the waterfall island only when chosen, front
/// styles, LED, the 2D drawings' boxes, and every decor id's picture.
final class Kitchen3DTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }
    private let noTex: (String) -> String? = { _ in nil }
    private func near(_ a: Double, _ b: Double, _ e: Double = 1e-6) -> Bool { abs(a - b) < e }

    private func room() -> Room {
        var r = Room(id: "r", floorId: "f", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        return r
    }
    private var bases: [String: WallBasis] { buildShell([room()], single: true).bases }

    /// An L kitchen as the app fills it.
    private func kitchen() -> Furniture {
        let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        return autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }
    private func build(_ f: Furniture, _ detail: Quality3 = .high, _ b: [String: WallBasis]? = nil) -> Furn3D {
        furniture3D([f], b ?? bases, ws, rgb, [], tex: noTex, detail: detail)
    }
    /// The faces drawn in look key of f.
    private func faces(_ d: Furn3D, _ f: Furniture, _ key: String) -> [Face3] {
        let l = pieceLooks(f, rgb, noTex, MAT_PRESETS)[key]
        return d.parts.filter { $0.look == l }.flatMap(\.faces)
    }
    private func top(_ d: Furn3D) -> Double { d.parts.flatMap(\.faces).flatMap(\.pts).map(\.y).max() ?? 0 }

    /* ---------------- handles ---------------- */

    func testHandleLengthsFollowTheRules() {
        // long verticals: 1024 on doors from 1400, 640 from 700, else 320; drawers 320 (as longHandleIds prices them)
        XCTAssertEqual(handleBarLen(LONG_V, door: true, h: 2000), 1024)
        XCTAssertEqual(handleBarLen(LONG_V, door: true, h: 1400), 1024)
        XCTAssertEqual(handleBarLen(LONG_V, door: true, h: 1399), 640)
        XCTAssertEqual(handleBarLen(LONG_V, door: true, h: 700), 640)
        XCTAssertEqual(handleBarLen(LONG_V, door: true, h: 699), 320)
        XCTAssertEqual(handleBarLen(LONG_V, door: false, h: 2000), 320)
        // a long handle chosen by its size keeps it; the usual skoba is 168 long (holes 128); a knob has no bar
        XCTAssertEqual(handleBarLen("handle640", door: true, h: 300), 640)
        XCTAssertEqual(handleBarLen("handleLong", door: true, h: 2000), 320)
        XCTAssertEqual(handleBarLen("", door: true, h: 700), 168)
        XCTAssertEqual(handleBarLen("handleKnob", door: true, h: 700), 0)
    }

    func testHandlesSitWhereTheMockupPutsThem() {
        // a base unit's door: upright near its opening edge, 45 mm under its top
        let b = handleSpot("", "door", 400, 700, .top)!
        XCTAssertTrue(b.vert && near(b.len, 168) && near(b.x, 400 - 33.6) && near(b.y, 700 - 45 - 84))
        // a wall unit's door: near its bottom
        let w = handleSpot("", "door", 400, 700, .bottom)!
        XCTAssertTrue(near(w.y, 45 + 84) && near(w.x, 400 - 33.6))
        // a drawer: across its middle, 50 mm under its top
        let dr = handleSpot("", "drawer", 600, 200)!
        XCTAssertTrue(!dr.vert && near(dr.x, 300) && near(dr.y, 150) && near(dr.len, 168))
        // a flap (the row to the ceiling): across, near its bottom
        XCTAssertTrue(near(handleSpot("", "flap", 600, 400)!.y, 45))
        // a tall door's long handle stays where asked (1 m up) as long as it fits on the door
        let t = handleSpot(LONG_V, "door", 600, 2100, .at(1000))!
        XCTAssertTrue(near(t.len, 1024) && near(t.y, 1000))
        XCTAssertTrue(near(handleSpot(LONG_V, "door", 600, 2100, .at(300))!.y, 45 + 512))
        // no handle is longer than its front less 80 mm; a front too small takes none
        XCTAssertTrue(near(handleSpot(LONG_V, "door", 400, 300, .top)!.len, 220))
        XCTAssertNil(handleSpot("", "drawer", 100, 150))
        // knobs: 42 mm in from a door's opening edge, 70 from its top; a drawer's in its middle, 60 under its top
        let k = handleSpot("handleKnob", "door", 400, 700, .top)!
        XCTAssertTrue(near(k.len, 0) && near(k.x, 358) && near(k.y, 630))
        let kd = handleSpot("handleKnob", "drawer", 600, 200)!
        XCTAssertTrue(near(kd.x, 300) && near(kd.y, 140))
    }

    func testKnobsAndLongHandlesAreDrawn() {
        let f = kitchen()
        let bar = faces(build(f), f, "handle").count
        let kn = withHandleType(f, "knob"), lg = withHandleType(f, "long")
        XCTAssertEqual(handleType(kn), "knob"); XCTAssertEqual(handleType(lg), "long")
        // a knob is a turned part (more faces than a bar's three rods), a long bar the same rods as a short one
        XCTAssertTrue(faces(build(kn), kn, "handle").count > bar)
        XCTAssertTrue(faces(build(lg), lg, "handle").count > 0)
        // the long ones are longer: the handles reach further up and down
        func span(_ fs: [Face3]) -> Double { let ys = fs.flatMap(\.pts).map(\.y); return (ys.max() ?? 0) - (ys.min() ?? 0) }
        XCTAssertTrue(span(faces(build(lg), lg, "handle")) >= span(faces(build(f), f, "handle")) - 1e-9)
    }

    /* ---------------- Gola ---------------- */

    func testGolaHasChannelsAndNoHandlesOnTheFronts() {
        let f = kitchen()
        let g = withHandleType(f, "gola")
        XCTAssertEqual(handleType(g), "gola")
        let d = build(g)
        let ch = faces(d, g, "gola")
        XCTAssertFalse(ch.isEmpty)
        XCTAssertTrue(faces(build(f), f, "gola").isEmpty)
        // the channels sit at the top of the base units (an oven housing has its own two higher up), 52 high, behind the fronts
        let baseTop = Double(f.modules.first { $0.type == "base" }.map { $0.elev + $0.h } ?? 0) / 1000
        let ys = ch.flatMap(\.pts).map(\.y).filter { $0 <= baseTop + 1e-9 }
        XCTAssertTrue(near(ys.max() ?? 0, baseTop))
        XCTAssertTrue((ys.min() ?? 0) <= baseTop - GOLA_H / 1000 + 1e-9)
        // fewer handle faces: only what is not a front's (a free-standing fridge's) is left
        XCTAssertTrue(faces(d, g, "handle").count < faces(build(f), f, "handle").count)
        // push latches: no handles on the fronts and no channel either
        let push = withHandleType(f, "push")
        XCTAssertTrue(faces(build(push), push, "gola").isEmpty)
        XCTAssertTrue(faces(build(push), push, "handle").count < faces(build(f), f, "handle").count)
    }

    /* ---------------- the crown ---------------- */

    func testCorniceAndTheRowToTheCeiling() {
        let f = kitchen()
        let none = top(build(f))
        let units = f.modules.filter { $0.type == "wall" || $0.type == "tall" }.map { $0.elev + $0.h }.max() ?? 0
        XCTAssertTrue(near(none, Double(units) / 1000))
        // the cornice's three layers: 22 + 36 + 18 = 76 mm over the units
        XCTAssertTrue(near(CORNICE_LAYERS.reduce(0.0) { $0 + $1.h }, 76))
        let c = withCrown(f, "cornice")
        XCTAssertEqual(crownOf(c), "cornice")
        XCTAssertTrue(near(top(build(c)), (Double(units) + 76) / 1000))
        // the row of units up to the ceiling: 4 mm short of it
        let up = withCrown(f, "ceiling")
        XCTAssertEqual(crownOf(up), "ceiling")
        XCTAssertTrue(near(top(furniture3D([up], bases, ws, rgb, [], tex: noTex, ceilH: 2700)), 2.696))
        XCTAssertTrue(near(top(furniture3D([up], bases, ws, rgb, [], tex: noTex, ceilH: 3000)), 2.996))
        XCTAssertEqual(ceilRowH(2178, 2700), 518)
        // no room left for a row: none
        XCTAssertEqual(ceilRowH(2650, 2700), 0)
    }

    /* ---------------- the island ---------------- */

    func testTheWaterfallOnlyWhenChosen() {
        var o = newFreeKitchen("Oshxona 1", "O", "O", [3000], 1800, 2700, ws)
        o.id = "o"
        let sh = buildShell([freeRoom(o)], single: true).bases
        // a worktop face reaching the floor: the waterfall's ends
        func reachesFloor(_ f: Furniture) -> Bool {
            build(f, .high, sh).parts.filter(\.slab).flatMap(\.faces).flatMap(\.pts).contains { $0.y < 0.01 }
        }
        XCTAssertFalse(reachesFloor(o))
        let w = look(o) { $0.waterfall = true }
        XCTAssertEqual(waterfallEnds(w), 2)
        XCTAssertTrue(reachesFloor(w))
        // without an island the option draws nothing
        var i = newFreeKitchen("Oshxona 2", "I", "I", [3000], 0, 2700, ws)
        i.id = "i"
        let si = buildShell([freeRoom(i)], single: true).bases
        let wi = look(i) { $0.waterfall = true }
        XCTAssertEqual(waterfallEnds(wi), 0)
        XCTAssertFalse(build(wi, .high, si).parts.filter(\.slab).flatMap(\.faces).flatMap(\.pts).contains { $0.y < 0.01 })
    }

    /* ---------------- fronts, LED, worktop ---------------- */

    func testFrontStylesAddTheirShapes() {
        let f = kitchen()
        let flat = faces(build(f), f, "front").count
        let sh = look(f) { $0.style = "shaker" }, fl = look(f) { $0.style = "fluted" }
        XCTAssertTrue(faces(build(sh), sh, "front").count > flat)
        XCTAssertTrue(faces(build(fl), fl, "front").count > faces(build(sh), sh, "front").count)
        // the 2D drawings keep plain fronts
        XCTAssertEqual(faces(build(fl, .flat), fl, "front").count, faces(build(f, .flat), f, "front").count)
    }

    func testTwoToneUpperFrontsTakeTheirOwnBoard() {
        var f = kitchen()
        f.mats.frontUp = "ag_white"
        let looks = pieceLooks(f, { $0 == "ag_white" ? 0xF2F2EF : 0xCDBFAE }, noTex, MAT_PRESETS)
        XCTAssertNotEqual(looks["frontUp"], looks["front"])
        // the acrylic board is gloss
        XCTAssertEqual(looks["frontUp"]?.clearcoat, 1)
        let d = furniture3D([f], bases, ws, { $0 == "ag_white" ? 0xF2F2EF : 0xCDBFAE }, [], tex: noTex)
        let up = d.parts.filter { $0.look == looks["frontUp"] }.flatMap(\.faces).flatMap(\.pts)
        // the upper fronts hang over the worktop
        XCTAssertFalse(up.isEmpty)
        XCTAssertTrue(up.allSatisfy { $0.y > Double(worktopTop(ws)) / 1000 })
    }

    func testTheLedGlowsOnlyOnAStrongPhone() {
        var f = kitchen()
        f.kx = KExtras(splash: 600, led: true)
        XCTAssertFalse(faces(build(f), f, "led").isEmpty)
        XCTAssertFalse(faces(build(f), f, "glow").isEmpty)
        XCTAssertTrue(faces(build(f, .low), f, "glow").isEmpty)
        XCTAssertFalse(faces(build(f, .low), f, "led").isEmpty)
        f.kx?.led = false
        XCTAssertTrue(faces(build(f), f, "led").isEmpty)
    }

    func testASlimWorktopSitsLowerAndTheSinkIsCutOut() {
        let f = kitchen()
        let slim = { () -> Furniture in var g = f; g.mats.top = "wt20m"; return g }()
        func topY(_ d: Furn3D) -> Double { d.parts.filter(\.slab).flatMap(\.faces).flatMap(\.pts).map(\.y).max() ?? 0 }
        XCTAssertTrue(near(topY(build(f)), Double(worktopTop(ws)) / 1000))
        XCTAssertTrue(near(topY(build(slim)), Double(worktopTop(ws) - 18) / 1000))
        // a sink unit's basin hangs under the worktop, its tap stands over it
        if f.modules.contains(where: { $0.app == "sink" }) {
            let basin = faces(build(f), f, "sinkIn").flatMap(\.pts).map(\.y)
            XCTAssertTrue((basin.min() ?? 1) < Double(worktopTop(ws) - 150) / 1000)
            XCTAssertTrue((faces(build(f), f, "faucet").flatMap(\.pts).map(\.y).max() ?? 0) > Double(worktopTop(ws) + 300) / 1000)
        }
    }

    func testThe2DDrawingsGetOnlyBoxes() {
        // PieceView reads the faces six at a time: every option of a kitchen still comes as boxes there
        var f = withCrown(look(kitchen()) { $0.style = "fluted"; $0.legs = true; $0.fglass = true; $0.hcol = "gold" }, "ceiling")
        f.kx = KExtras(splash: 600, cornice: false, led: true)
        f.mats.top = "wt38m"; f.mats.splash = "skPrint"
        let d = build(f, .flat)
        XCTAssertTrue(d.parts.allSatisfy { $0.faces.count % 6 == 0 })
        XCTAssertTrue(d.parts.allSatisfy { $0.faces.allSatisfy { $0.pts.count == 4 } })
        // and the full picture has every face lying flat with its grain in it
        for p in build(f).parts { for fc in p.faces {
            XCTAssertTrue(abs((fc.grain ?? V3(0, 0, 0)).dot(fc.n)) < 1e-6)
            XCTAssertTrue(fc.pts.allSatisfy { abs(($0 - fc.pts[0]).dot(fc.n)) < 1e-9 })
        } }
        // doors still open, the parts stay as many
        let shut = build(f)
        let open = furniture3D([f], bases, ws, rgb, Set(shut.keys), tex: noTex)
        XCTAssertEqual(shut.parts.count, open.parts.count)
    }

    /* ---------------- pictures ---------------- */

    func testEveryDecorIdResolvesToAPicture() {
        for id in TEX_IDS where id != "fluted" && id != "fluted_glass" {
            guard let s = texSource(id) else { XCTFail(id); continue }
            XCTAssertTrue(TEX_FILES.contains(s.file), id)
        }
        XCTAssertNil(texSource("fluted")); XCTAssertNil(texSource("fluted_glass"))
        // the table Android uses
        XCTAssertEqual(texSource("oak_light")?.file, "oak_halifax")
        XCTAssertEqual(texSource("oak_golden")?.file, "oak_craft")
        XCTAssertEqual(texSource("onyx_beige")?.file, "travertine")
        XCTAssertEqual(texSource("tile_white")?.file, "tile_subway")
        XCTAssertEqual(texSource("boucle")?.file, "fabric_boucle")
        XCTAssertEqual(texSource("velvet")?.file, "fabric_weave")
        // tobacco is Halifax recoloured darker, dark oak wenge lighter (to the decors' own colours, as Android)
        XCTAssertEqual(texSource("oak_tobacco")?.file, "oak_halifax")
        XCTAssertEqual(texSource("oak_tobacco")?.avg, 0x7A5A40)
        XCTAssertEqual(texSource("oak_dark")?.file, "wenge")
        XCTAssertEqual(texSource("oak_dark")?.avg, 0x5A3F2E)
        XCTAssertEqual(texSource("onyx_beige")?.avg, 0xE8DBC2)
        XCTAssertNil(texSource("oak_light")?.avg)
        // every decor board's picture is known
        for m in DECOR_PRESETS { if let t = m.tex { XCTAssertNotNil(texSource(t), m.id) } }
        // the shared folder's own file comes first
        XCTAssertEqual(texFiles("walnut", 256).first, "256/walnut.webp")
    }

    func testThePicturesShipInTheApp() {
        // the shared tex folder is in the app (project.yml), and its WebP pictures decode
        let root = Bundle.main.bundleURL.appendingPathComponent("tex", isDirectory: true)
        for f in TEX_FILES where f != "skinali_print" {
            for px in [512, 256] {
                let u = root.appendingPathComponent("\(px)/\(f).webp")
                XCTAssertTrue(FileManager.default.fileExists(atPath: u.path), u.path)
            }
        }
        XCTAssertNotNil(UIImage(contentsOfFile: root.appendingPathComponent("512/oak_halifax.webp").path)?.cgImage)
    }

    func testAPrintedSkinaliIsLaidUprightFromItsCorner() {
        let f = Face3(n: V3(0, 0, 1), pts: [V3(0, 0.9, 0), V3(3, 0.9, 0), V3(3, 1.5, 0), V3(0, 1.5, 0)], grain: V3(-1, 0, 0))
        let uv = fitUVs(f, Look(rgb: 0, uvScale: 3, uvScaleV: 0.6, fit: true))
        // 0…1 each way over a 3 m × 0.6 m repeat, v up the wall
        XCTAssertTrue(uv.allSatisfy { $0.x >= -1e-9 && $0.x <= 1 + 1e-9 && $0.y >= -1e-9 && $0.y <= 1 + 1e-9 })
        XCTAssertTrue(near(uv[2].y - uv[1].y, 1) && near(uv[0].y, 0))
        // seen from the room, u runs left to right
        XCTAssertTrue(uv[1].x > uv[0].x)
    }
}
