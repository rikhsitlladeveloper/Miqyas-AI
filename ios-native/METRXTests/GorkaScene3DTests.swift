import XCTest
@testable import METRX

/// The gorka's and the big table's lit 3D (Geo/GorkaScene3D.swift; Android Gorka3DTest): what is drawn, in which looks,
/// and what a weak phone leaves out.
final class GorkaScene3DTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }
    private func piece(_ id: String) -> Furniture { pieceOf(fModel(id)!, [:], ws, id) }
    /// The piece in its made-up room; the boards' decor pictures from the presets (the worktop's marble).
    private func scene(_ f: Furniture, decor: Bool = true) -> Furn3D {
        furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, [], decor: decor)
    }
    private func looks(_ f: Furniture, decor: Bool = true) -> [Look] { scene(f, decor: decor).parts.compactMap(\.look) }
    private func pieceLook(_ f: Furniture, _ key: String) -> Look? { pieceLooks(f, rgb, { id in MAT_PRESETS.first { $0.id == id }?.tex }, MAT_PRESETS)[key] }
    private func faces(_ d: Furn3D) -> Int { d.parts.reduce(0) { $0 + $1.faces.count } }

    func testTheGorkaHasItsTvGlassAndDishes() {
        let f = piece("gorka")
        let ls = looks(f)
        // the TV: a black-glass panel with a faintly lit screen; the panel's stone slab; glass doors and shelves; dishes
        XCTAssertTrue(ls.contains(GK_TV_SCREEN)); XCTAssertTrue(GK_TV_SCREEN.emissive > 0.1 && GK_TV_SCREEN.emissive <= 1)
        XCTAssertTrue(ls.contains(pieceLook(f, "bglass")!))
        XCTAssertTrue(ls.contains { $0.tex == "marble_white" })
        XCTAssertTrue(ls.contains(pieceLook(f, "clear")!))
        XCTAssertTrue(ls.contains(GK_PORCELAIN))
        // no LED without it in the look
        XCTAssertFalse(ls.contains(pieceLook(f, "led")!))
        // a weak phone leaves the dishes and the books out, and draws fewer faces
        let light = looks(f, decor: false)
        XCTAssertFalse(light.contains(GK_PORCELAIN)); XCTAssertTrue(light.contains(GK_TV_SCREEN))
        XCTAssertTrue(faces(scene(f, decor: false)) < faces(scene(f)))
        // the same looks are one part (the dishes of both towers are one)
        XCTAssertEqual(scene(f).parts.filter { $0.look == GK_PORCELAIN }.count, 1)
        // the low tier is a weak phone: no dishes there either
        let low = furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, [], detail: .low)
        XCTAssertFalse(low.parts.contains { $0.look == GK_PORCELAIN })
    }

    func testLedSlatsMouldingsAndTheCornice() {
        let f = withLook(piece("gorka")) { l in var n = l; n.led = true; n.crown = "cornice"; return n }
        let r = gorkaRoles(f)!
        let leds = r.ups.flatMap { gorkaBox(f, $0, ws, true) }.filter { $0.key == "led" }
        XCTAssertEqual(leds.count, 4)
        XCTAssertTrue(gorkaBox(f, r.base!, ws, true).contains { $0.key == "led" }); XCTAssertTrue(gorkaBox(f, r.bridge!, ws, true).contains { $0.key == "led" })
        XCTAssertTrue(looks(f).contains(pieceLook(f, "led")!))
        // the cornice: three mouldings over each tower and the bridge (none over a drawer box)
        XCTAssertEqual(gorkaBox(f, r.ups[0], ws, false).filter { $0.key == "frontUp" }.count, 3)
        XCTAssertTrue(gorkaBox(f, r.lows[0], ws, false).isEmpty)
        // the wardrobe's own section LED and cornice are not drawn on top of the gorka's
        XCTAssertEqual(scene(f).parts.filter { $0.look == pieceLook(f, "glow") }.count, 0)
        // slats: about one every 45 mm over the panel, in the wood accent (walnut without one)
        let slats = withGorkaPanel(f, panel: "slats")
        let p = gorkaRoles(slats)!.panel!
        let boxes = tvPanel(slats, p, ws)
        XCTAssertEqual(boxes.filter { $0.look?.tex == "walnut" }.count, 41)
        XCTAssertEqual(guestScene(slats, p, ws)?.own, true)
        let oak = withLook(slats) { l in var n = l; n.accent = "wd_halifax"; return n }
        XCTAssertEqual(tvPanel(oak, p, ws).filter { $0.key == "accent" }.count, 41)
        // mouldings: a frame of four in the fronts' board, over the panel's board
        let mould = withGorkaPanel(f, panel: "mould")
        XCTAssertEqual(tvPanel(mould, gorkaRoles(mould)!.panel!, ws).filter { $0.look == nil && $0.key == nil }.count, 4 + 1)
        // the TV is held to the panel
        let big = withGorkaPanel(piece("gorka"), tv: 85)
        let tv = tvPanel(big, gorkaRoles(big)!.panel!, ws).filter { $0.look == GK_TV_SCREEN }
        XCTAssertEqual(tv.count, 1)
        XCTAssertTrue(tv[0].a1 - tv[0].a0 <= 1840 - 40 + 1e-6)
    }

    func testTheBigTableHasItsChairsAndPendant() {
        let f = withPreset(piece("dining12"), "twotone", fresh: true)
        let m = wardOfF(f)!
        let g = guestScene(f, m, ws)!
        XCTAssertTrue(g.own)
        let fabric = gkFabricLook(f)
        // twelve chairs of six boxes each (seat, back, four legs), seat and back in the look's fabric (olive velvet)
        XCTAssertEqual(g.boxes.filter { $0.look == fabric }.count, 24)
        XCTAssertEqual(fabric.rgb, rgbOf(LOOK_FABRICS.first { $0.key == "olive" }!.rgb))
        // the stone-look top
        XCTAssertTrue(g.boxes.contains { $0.key == "top" && $0.y1 == Double(m.h) })
        // the pendant and its light with the decor only
        XCTAssertTrue(g.boxes.contains { $0.key == "led" })
        let light = guestScene(f, m, ws, decor: false)!
        XCTAssertFalse(light.boxes.contains { $0.key == "led" || $0.look == GK_PORCELAIN })
        XCTAssertEqual(light.boxes.filter { $0.look == fabric }.count, 24)
        // the whole scene builds, the chairs merged into one part
        XCTAssertEqual(scene(f).parts.filter { $0.look == fabric }.count, 1)
        // an ordinary table is drawn as before
        XCTAssertNil(guestScene(piece("dining"), wardOfF(piece("dining"))!, ws))
    }

    func testTexturesAreTheBundledOnes() {
        XCTAssertEqual(texSource("oak_light")?.file, "oak_halifax"); XCTAssertEqual(texSource("onyx_beige")?.file, "travertine")
        XCTAssertEqual(texSource("boucle")?.file, "fabric_boucle")
        XCTAssertNil(texSource("fluted")); XCTAssertEqual(texSource("walnut")?.file, "walnut")
        // the chairs' fabrics and the slats' walnut are pictures the app has
        for k in ["walnut", "boucle", "velvet", "fabric", "marble_white"] { XCTAssertEqual(texSource(k).map { TEX_FILES.contains($0.file) }, true, k) }
        XCTAssertEqual(GK_WALNUT.tex, "walnut")
    }
}
