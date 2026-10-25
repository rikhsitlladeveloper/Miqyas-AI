import XCTest
@testable import METRX

/// The lit 3D's foundation ("modern furniture 3D" part 1, 25 Oct 2026): texture coordinates in metres with the grain
/// along each board's long side, the looks of the furniture's materials, and the automatic quality tier.
final class Modern3DTests: XCTestCase {
    private let ws = Workshop()
    private func near(_ a: Double, _ b: Double, _ e: Double = 1e-9) -> Bool { abs(a - b) < e }
    private func near(_ a: V3, _ b: V3) -> Bool { (a - b).len < 1e-9 }

    /* ---------------- texture coordinates ---------------- */

    func testALevelBoardRunsItsGrainAlongItsLength() {
        // a shelf 800 long (x), 18 thick (y), 500 deep (z): every face but its two ends has the grain along x
        let g = boxGrains(V3(0.8, 0, 0), V3(0, 0.018, 0), V3(0, 0, 0.5))
        XCTAssertEqual(g.count, 6)
        for k in [0, 1, 4, 5] { XCTAssertTrue(near(g[k], V3(1, 0, 0)), "face \(k)") }
        // the ends (spanned by the depth and the thickness) run along the depth, their longer side
        XCTAssertTrue(near(g[2], V3(0, 0, 1)) && near(g[3], V3(0, 0, 1)))
    }

    func testAnUprightBoardRunsItsGrainUp() {
        // a cabinet side: 18 along the wall, 720 high, 560 deep: the long side is the height
        let g = boxGrains(V3(0.018, 0, 0), V3(0, 0.72, 0), V3(0, 0, 0.56))
        // its big faces (spanned by the height and the depth) run up
        XCTAssertTrue(near(g[2], V3(0, 1, 0)) && near(g[3], V3(0, 1, 0)))
        // its front edge (the thickness and the height) runs up too
        XCTAssertTrue(near(g[0], V3(0, 1, 0)))
        // its top and bottom ends run along the depth
        XCTAssertTrue(near(g[4], V3(0, 0, 1)))
    }

    func testUVsAreMetresAlongAndAcrossTheGrain() {
        // a door 600 wide and 720 high facing +z, grain up
        let f = Face3(n: V3(0, 0, 1), pts: [V3(0, 0, 0), V3(0.6, 0, 0), V3(0.6, 0.72, 0), V3(0, 0.72, 0)], grain: V3(0, 1, 0))
        let uv = faceUVs(f, Look(rgb: 0, uvScale: 1))
        // u runs up the door (0 … 0.72 m), v across it (0.6 m)
        XCTAssertTrue(near(uv[2].x - uv[0].x, 0.72) && near(abs(uv[1].y - uv[0].y), 0.6))
        XCTAssertTrue(near(uv[1].x - uv[0].x, 0))
        // one repeat per 1.2 m: the same door covers 0.6 of a picture along the grain
        let w = faceUVs(f, .wood(0xA27A53, "oak_light"))
        XCTAssertTrue(near(w[2].x - w[0].x, 0.6))
        // a stone slab is 3.2 m along and 1.6 m across
        let s = faceUVs(f, .stone(0xF1EFEB, "marble_white"))
        XCTAssertTrue(near(s[2].x - s[0].x, 0.72 / 3.2) && near(abs(s[1].y - s[0].y), 0.6 / 1.6))
        // a picture with its grain up the image swaps u and v
        var rot = Look(rgb: 0, uvScale: 1); rot.texRot = true
        let r = faceUVs(f, rot)
        XCTAssertTrue(near(r[2].y - r[0].y, 0.72) && near(r[1].y - r[0].y, 0))
    }

    func testThePictureIsNeverMirrored() {
        // u, v and the normal turn the right way on faces of every direction, with a grain or without
        let ns = [V3(1, 0, 0), V3(-1, 0, 0), V3(0, 1, 0), V3(0, -1, 0), V3(0, 0, 1), V3(0, 0, -1), V3(0.6, 0, 0.8)]
        for n in ns {
            for g in [nil, V3(0, 1, 0), V3(1, 0, 0), V3(0, 0, 1)] as [V3?] {
                let (u, v) = uvAxes(n, g)
                XCTAssertTrue(near(u.len, 1) && near(v.len, 1), "\(n)")
                XCTAssertTrue(near(u.dot(n), 0) && near(v.dot(n), 0) && near(u.dot(v), 0), "\(n)")
                XCTAssertTrue(near(u.cross(v), n), "\(n) \(String(describing: g))")
            }
        }
        // a wall facing +z without a grain: the picture's u runs along it, v up
        let (u, v) = uvAxes(V3(0, 0, 1), nil)
        XCTAssertTrue(near(u, V3(1, 0, 0)) && near(v, V3(0, 1, 0)))
    }

    func testFurnitureBoardsCarryTheirGrain() {
        let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        let f = autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
        let bases = buildShell([room()], single: true).bases
        let d = furniture3D([f], bases, ws, { _ in 0xCDBFAE }, [])
        // every face of every board has a grain lying in the face
        for p in d.parts { for fc in p.faces {
            guard let g = fc.grain else { XCTFail("a face without grain"); return }
            XCTAssertTrue(abs(g.dot(fc.n)) < 1e-6)
        } }
        // the carcass: some side faces wall A's direction (x) with its grain up (a side is taller than deep)
        let carcass = furnLooks(f.mats, { _ in 0xCDBFAE }, { _ in nil })["carcass"]!
        let side = d.parts.filter { $0.look == carcass }.flatMap(\.faces).filter { abs($0.n.x) > 0.99 }
        XCTAssertTrue(side.contains { abs(($0.grain ?? V3(0, 0, 0)).y) > 0.99 })
        // carcass and fronts of one colour are still apart (each its own look), and a door opening keeps the parts
        XCTAssertTrue(d.parts.contains { $0.look == carcass } && d.parts.contains { $0.look?.roughness == 0.8 })
        let opened = furniture3D([f], bases, ws, { _ in 0xCDBFAE }, Set(d.keys))
        XCTAssertEqual(d.parts.count, opened.parts.count)
    }

    func testABoardWithADecorPictureGetsIt() {
        let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        let f = autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
        let bases = buildShell([room()], single: true).bases
        let d = furniture3D([f], bases, ws, { _ in 0xA27A53 }, [], tex: { $0 == f.mats.front ? "oak_golden" : nil })
        let fronts = d.parts.filter { $0.look?.tex == "oak_golden" }
        XCTAssertFalse(fronts.isEmpty)
        // the 2D drawings keep the board's colour
        XCTAssertTrue(fronts.allSatisfy { $0.rgb == 0xA27A53 })
    }

    private func room() -> Room {
        var r = Room(id: "r", floorId: "f", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        return r
    }

    /* ---------------- looks ---------------- */

    func testEveryMaterialKeyHasALook() {
        let l = furnLooks(FMats(), { _ in 0xF5F5F2 }, { _ in nil })
        for k in ["carcass", "front", "back", "top", "splash", "metal", "handle", "mirror", "glass", "clear", "led", "mattress", "lamel", "dark", "white", "hi"] {
            XCTAssertNotNil(l[k], k)
        }
        // glass is see-through, the mirror and metal are metal, the LED glows, gloss is not what a board starts with
        XCTAssertTrue(l["clear"]!.alpha < 0.5 && l["glass"]!.alpha < 1)
        XCTAssertEqual(l["mirror"]!.metallic, 1); XCTAssertTrue(l["mirror"]!.roughness < 0.1)
        XCTAssertEqual(l["metal"]!.metallic, 1)
        XCTAssertTrue(l["led"]!.glows && !l["front"]!.glows)
        XCTAssertEqual(l["front"]!.clearcoat, 0)
        // the plain picture keeps today's colours
        XCTAssertEqual(l["metal"]!.flatRgb, 0xC5CBD4); XCTAssertEqual(l["mirror"]!.flatRgb, 0xC9D3DD); XCTAssertEqual(l["clear"]!.flatRgb, 0xBFD8E8)
        XCTAssertEqual(l["front"]!.flatRgb, 0xF5F5F2)
    }

    func testBoardFinishesAndDecors() {
        XCTAssertEqual(Look.board(0x41454C, nil, finish: "gloss").clearcoat, 1)
        XCTAssertTrue(Look.board(0x41454C, nil, finish: "gloss").roughness < 0.1)
        XCTAssertTrue(Look.board(0x41454C, nil).roughness > 0.7)
        let wood = Look.board(0xA27A53, "walnut")
        XCTAssertEqual(wood.tex, "walnut"); XCTAssertEqual(wood.uvScale, 1.2)
        let stone = Look.board(0xF1EFEB, "marble_white")
        XCTAssertEqual(stone.uvScale, 3.2); XCTAssertTrue(stone.clearcoat > 0)
    }

    func testAWeakPhoneGetsTheSimplerLook() {
        let g = Look.gloss(0x19191B).lowered()
        XCTAssertEqual(g.clearcoat, 0); XCTAssertTrue(g.roughness >= 0.28)
        let m = Look.mirror(0xC9D3DD).lowered()
        XCTAssertEqual(m.metallic, 0.35); XCTAssertTrue(m.roughness >= 0.32)
        // a matte board does not change
        XCTAssertEqual(Look.matte(0xEFEEEA, 0.7).lowered(), Look.matte(0xEFEEEA, 0.7))
    }

    func testABoardsDecorPictureIsKeptInItsMat() throws {
        let m = Mat("halifax", "board", "Halifax", 18, rgb: "#A27A53", tex: "oak_golden")
        let back = try JSONDecoder().decode(Mat.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(back.tex, "oak_golden")
        // a board saved before decor pictures has none
        let old = try JSONDecoder().decode(Mat.self, from: Data(##"{"id":"x","rgb":"#FFFFFF"}"##.utf8))
        XCTAssertNil(old.tex)
    }

    /* ---------------- quality ---------------- */

    private let GB: UInt64 = 1_000_000_000

    func testTheTierFollowsThePhone() {
        // iPhone 8 and X: low; iPhone 12, 13, 15, the SE 3: high
        XCTAssertEqual(quality3("auto", memory: 2 * GB, hot: false, model: "iPhone10,1"), .low)
        XCTAssertEqual(quality3("auto", memory: 3 * GB, hot: false, model: "iPhone10,3"), .low)
        XCTAssertEqual(quality3("auto", memory: 4 * GB, hot: false, model: "iPhone13,2"), .high)
        XCTAssertEqual(quality3("auto", memory: 6 * GB, hot: false, model: "iPhone15,4"), .high)
        XCTAssertEqual(quality3("auto", memory: 4 * GB, hot: false, model: "iPhone14,6"), .high)
        // in between by memory: the iPhone 11 (4 GB) high, the SE 2 and XR (3 GB) low
        XCTAssertEqual(quality3("auto", memory: 4 * GB, hot: false, model: "iPhone12,1"), .high)
        XCTAssertEqual(quality3("auto", memory: 3 * GB, hot: false, model: "iPhone12,8"), .low)
        XCTAssertEqual(quality3("auto", memory: 3 * GB, hot: false, model: "iPhone11,8"), .low)
        // a hot phone and a small memory go low whatever the model
        XCTAssertEqual(quality3("auto", memory: 6 * GB, hot: true, model: "iPhone15,4"), .low)
        XCTAssertEqual(quality3("auto", memory: 2 * GB, hot: false, model: "iPhone16,1"), .low)
        // an iPad or the Mac by memory
        XCTAssertEqual(quality3("auto", memory: 8 * GB, hot: false, model: "iPad13,4"), .high)
        XCTAssertEqual(quality3("auto", memory: 3 * GB, hot: false, model: "iPad7,5"), .low)
    }

    func testTheSettingWins() {
        XCTAssertEqual(quality3("high", memory: 2 * GB, hot: true, model: "iPhone10,1"), .high)
        XCTAssertEqual(quality3("low", memory: 8 * GB, hot: false, model: "iPhone16,1"), .low)
        XCTAssertEqual(quality3("flat", memory: 8 * GB, hot: false, model: "iPhone16,1"), .flat)
        // anything else is auto
        XCTAssertEqual(quality3("", memory: 8 * GB, hot: false, model: "iPhone16,1"), .high)
        XCTAssertEqual(Quality3.high.texPx, 512); XCTAssertEqual(Quality3.low.texPx, 256)
    }

    func testModelNumbers() {
        XCTAssertEqual(iPhoneMajor("iPhone13,2"), 13)
        XCTAssertEqual(iPhoneMajor("iPhone9,3"), 9)
        XCTAssertNil(iPhoneMajor("iPad13,4"))
        XCTAssertNil(iPhoneMajor("arm64"))
    }

    func testPictureFilesAreLookedForBySize() {
        let f = texFiles("oak_light", 256)
        XCTAssertEqual(f.first, "oak_light_256.jpg")
        XCTAssertTrue(f.firstIndex(of: "oak_light_256.webp")! < f.firstIndex(of: "oak_light_512.jpg")!)
        XCTAssertTrue(f.contains("oak_light.png"))
        XCTAssertEqual(texFiles("walnut", 512).first, "walnut_512.jpg")
    }
}
