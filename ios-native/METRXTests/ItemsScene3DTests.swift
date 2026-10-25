import XCTest
@testable import METRX

/// The rest of the furniture in the modern 3D ("modern furniture 3D" part 6b; Geo/ItemsScene3D.swift): a bed's headboard
/// styles, the soft wall panel only when chosen, legs or a hidden base, a table's top in its decor with round corners,
/// the bathroom's tap and a hall panel's hooks in the handle colour, and every face drawn sound.
final class ItemsScene3DTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }
    /// The piece in its made-up room; the boards' decor pictures from the presets.
    private func build(_ f: Furniture, _ detail: Quality3 = .high, open: Set<String> = []) -> Furn3D {
        furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, open, detail: detail)
    }
    private func looks(_ f: Furniture) -> [String: Look] { pieceLooks(f, rgb, { id in MAT_PRESETS.first { $0.id == id }?.tex }, MAT_PRESETS) }
    /// The faces drawn in look l.
    private func faces(_ d: Furn3D, _ l: Look?) -> [Face3] { d.parts.filter { $0.look == l }.flatMap(\.faces) }
    /// f with each item box's options changed by fn.
    private func opt(_ f: Furniture, _ fn: (inout ItemOpt) -> Void) -> Furniture {
        var g = f
        g.modules = f.modules.map { m in
            guard ITEM_MODS.contains(m.type) else { return m }
            var x = m; var o = x.opt ?? ItemOpt(); fn(&o); x.opt = o
            return x
        }
        return g
    }

    /* ---------------- beds ---------------- */

    func testHeadboardStylesAddTheirPads() {
        // over a 1600 × 550 headboard: none on a plain board, eleven channels, four squares, one tufted slab
        XCTAssertEqual(softPads("", 0, 1600, 450, 1000).count, 0)
        XCTAssertEqual(softPads("vertical", 0, 1600, 450, 1000).count, 11)
        XCTAssertEqual(softPads("panels", 0, 1600, 450, 1000).count, 4)
        XCTAssertEqual(softPads("tufted", 0, 1600, 450, 1000).count, 1)
        XCTAssertTrue(softPads("vertical", 0, 1600, 450, 1000).allSatisfy { $0.a1 - $0.a0 > 130 && $0.a1 - $0.a0 < 150 })
        // a tufted slab's buttons in a diamond lattice 80 apart, none near its edge; the puffs between them
        let bt = tuftButtons(0, 1600, 450, 1000)
        XCTAssertTrue(bt.count > 40)
        XCTAssertTrue(bt.allSatisfy { $0.a0 >= 40 && $0.a0 <= 1560 && $0.y0 >= 490 && $0.y0 <= 960 })
        XCTAssertFalse(bt.contains { b in bt.contains { $0 != b && abs($0.a0 - b.a0) < 1 && abs($0.y0 - b.y0 - TUFT_STEP) < 1 } })
        XCTAssertFalse(tuftPuffs(0, 1600, 450, 1000).isEmpty)
        // in 3D (a weak phone: no bedding in the fabric): no fabric on a plain board, each style its pads
        let bed = piece("bed")
        func fabric(_ head: String, _ q: Quality3) -> Int {
            let f = look(bed) { $0.head = head; $0.fabric = "olive" }
            return faces(build(f, q), looks(f)["fabric"]).count
        }
        XCTAssertEqual(fabric("", .low), 0)
        let v = fabric("vertical", .low), p = fabric("panels", .low), tf = fabric("tufted", .low)
        XCTAssertTrue(v > p && p > 0 && tf > 0)
        // the strong phone adds the tufting's puffs; the 2D drawings have no upholstery (boxes only)
        XCTAssertTrue(fabric("tufted", .high) > tf + 100)
        XCTAssertEqual(fabric("vertical", .flat), 0)
        // the fabric has the mockup's sheen (a velvet's stronger), a weak phone none
        let olive = looks(look(bed) { $0.fabric = "olive" })["fabric"]!
        XCTAssertNotNil(olive.sheen); XCTAssertNil(olive.lowered().sheen)
        XCTAssertEqual(olive, gkFabricLook(look(bed) { $0.fabric = "olive" }))
        XCTAssertTrue(itSheen(0x646C48, velvet: true) > itSheen(0x646C48, velvet: false))
    }

    func testTheSoftWallPanelOnlyWhenOn() {
        let off = look(piece("bed")) { $0.head = "vertical" }
        let on = look(off) { $0.panel = true }
        let l = looks(on)
        // the lighter fabric's pads (a weak phone: no cushions in it), the LED over the wood cap
        XCTAssertTrue(faces(build(off, .low), l["fabric2"]).isEmpty)
        XCTAssertFalse(faces(build(on, .low), l["fabric2"]).isEmpty)
        XCTAssertTrue(faces(build(off), l["led"]).isEmpty)
        XCTAssertFalse(faces(build(on), l["led"]).isEmpty)
        // its glow up the wall on a strong phone only
        XCTAssertFalse(faces(build(on), l["glow"]).isEmpty)
        XCTAssertTrue(faces(build(on, .low), l["glow"]).isEmpty)
        // the 2D drawings show it as boxes (a gallery card fits round it)
        let flat = build(on, .flat)
        XCTAssertFalse(faces(flat, l["fabric2"]).isEmpty)
        XCTAssertTrue(flat.parts.allSatisfy { $0.faces.count % 6 == 0 })
        // reaching 400 past each side where the wall allows (the price's rule, Core/PieceLook.swift); over a tall headboard
        let bm = Module(id: "bm", type: "bed", w: 1700, h: 450, d: 2100, opt: ItemOpt(bed: "legs", hb: 1000))
        var tallHb = bm; tallHb.opt = ItemOpt(bed: "legs", hb: 1600)
        XCTAssertEqual(softPanelSpan(bm, nil, 10, 1720), SoftPad(a0: -10, a1: 1710, y0: PANEL_Y0, y1: PANEL_Y1))
        XCTAssertEqual(softPanelSpan(bm, nil, 1000, 4000), SoftPad(a0: -400, a1: 2100, y0: PANEL_Y0, y1: PANEL_Y1))
        XCTAssertEqual(softPanelSpan(tallHb, nil, 1000, 4000)?.y1, 1750)
        // moved into the room: kept whole at a wall, none out in the room
        XCTAssertEqual(softPanelSpan(bm, Pose("A", 1000, 0), 0, 1700), SoftPad(a0: -400, a1: 2100, y0: PANEL_Y0, y1: PANEL_Y1))
        XCTAssertNil(softPanelSpan(bm, Pose("A", 1000, 600), 0, 1700))
        // nothing behind the headboard: a pad over it starts above it
        let span = softPanelSpan(bm, nil, 1000, 4000)!
        for head in ["", "vertical", "tufted", "panels"] {
            let pads = panelPads(head, span, 1700, 1000)
            XCTAssertFalse(pads.isEmpty, head)
            XCTAssertTrue(pads.allSatisfy { $0.a1 <= 0 || $0.a0 >= 1700 || $0.y0 >= 1004 }, head)
        }
        // only a bed has one
        let table = look(piece("dining")) { $0.panel = true }
        XCTAssertTrue(faces(build(table, .low), looks(table)["fabric2"]).isEmpty)
    }

    func testLegsOrAHiddenBase() {
        let bed = piece("bed", ["bt": 0])
        let m = bed.modules.first { $0.type == "bed" }!
        XCTAssertEqual(m.opt?.bed, "legs")
        // before the design: its legs as they were; with one, the mockup's hidden base unless metal legs are chosen
        XCTAssertEqual(bedFoot(m, nil), "legs")
        XCTAssertEqual(bedFoot(m, PieceLook()), "base")
        XCTAssertEqual(bedFoot(m, PieceLook(legs: true)), "legs")
        var dm = m; dm.opt?.bed = "drawers"
        XCTAssertEqual(bedFoot(dm, PieceLook()), "box")
        XCTAssertEqual(bedFoot(Module(id: "t", type: "table", w: 1200, h: 750, d: 800, opt: ItemOpt()), PieceLook()), "box")
        // in 3D: the black base and no legs, or the legs round in the handle colour and no base
        let base = look(bed) { $0.hcol = "gold" }
        let legs = look(base) { $0.legs = true }
        let gold = handleLook("gold")
        XCTAssertFalse(faces(build(base), IT_BASE).isEmpty)
        XCTAssertTrue(faces(build(base), gold).isEmpty)
        XCTAssertTrue(faces(build(legs), IT_BASE).isEmpty)
        let lf = faces(build(legs), gold)
        XCTAssertFalse(lf.isEmpty)
        XCTAssertTrue(lf.contains { $0.pts.count >= 8 })
        // a bed with drawers has neither: its sides reach the floor
        let dr = look(piece("bed", ["bt": 1])) { $0.hcol = "gold" }
        XCTAssertTrue(faces(build(dr), IT_BASE).isEmpty)
        // the 2D drawings: the base a box, the legs' squares gone under it
        let flat = build(base, .flat)
        XCTAssertEqual(faces(flat, IT_BASE).count, 6)
        XCTAssertTrue(faces(flat, looks(base)["metal"]).isEmpty)
    }

    func testTheBeddingAndTheLiftBedsSlats() {
        let lift = look(piece("bed", ["bt": 2])) { $0.head = "panels" }
        let l = looks(lift)
        let shut = build(lift)
        // linen pillows, the duvet over the foot, a runner in the fabric; a weak phone no duvet
        XCTAssertFalse(faces(shut, l["linen"]).isEmpty)
        XCTAssertFalse(faces(shut, l["duvet"]).isEmpty)
        XCTAssertTrue(faces(build(lift, .low), l["duvet"]).isEmpty)
        // the slats rise with the mattress
        let key = shut.keys.first { $0.hasSuffix(":lift") }!
        let open = build(lift, open: [key])
        func top(_ fs: [Face3]) -> Double { fs.flatMap(\.pts).map(\.y).max() ?? 0 }
        XCTAssertTrue(top(faces(open, l["lamel"])) > top(faces(shut, l["lamel"])) + 0.5)
        XCTAssertTrue(top(faces(open, l["duvet"])) > top(faces(shut, l["duvet"])) + 0.5)
        XCTAssertEqual(shut.parts.count, open.parts.count)
        // a bunk bed's two mattresses each with a pillow and a duvet: one low, one up on its deck
        let ys = faces(build(piece("bunk")), looks(piece("bunk"))["duvet"]).flatMap(\.pts).map(\.y)
        XCTAssertTrue((ys.min() ?? 9) < 0.8 && (ys.max() ?? 0) > 1.0)
    }

    /* ---------------- tables ---------------- */

    func testTableTopsTakeTheirDecorAndRoundCorners() {
        var t = opt(piece("dining")) { $0.top = "wt"; $0.round = false; $0.legs = "metal4" }
        t.mats.top = "wt38m"
        t = look(t) { $0.hcol = "brass" }
        let top = looks(t)["top"]!
        XCTAssertEqual(top.tex, "marble_white")
        let tf = faces(build(t), top)
        // one slab with a soft edge, not a box
        XCTAssertTrue(tf.count > 6)
        func cornerHit(_ fs: [Face3]) -> Bool {
            let ps = fs.flatMap(\.pts)
            guard let x0 = ps.map(\.x).min(), let z0 = ps.map(\.z).min() else { return false }
            return ps.contains { abs($0.x - x0) < 1e-6 && abs($0.z - z0) < 1e-6 }
        }
        XCTAssertTrue(cornerHit(tf))
        // round corners: nothing at the corner of its plan
        let r = opt(t) { $0.round = true }
        XCTAssertFalse(cornerHit(faces(build(r), top)))
        XCTAssertEqual(topEdgeR(38), 6); XCTAssertEqual(topEdgeR(16), 3)
        // the four metal legs round, in the handle colour
        let legs = faces(build(t), handleLook("brass"))
        XCTAssertTrue(legs.contains { $0.pts.count >= 8 })
        // a front board top (two glued) is soft-edged too, in the fronts' look: faces sloping round its edge
        let ldsp = opt(t) { $0.top = "ldsp" }
        XCTAssertTrue(faces(build(ldsp), top).isEmpty)
        XCTAssertTrue(faces(build(ldsp), looks(ldsp)["front"]).contains { abs($0.n.y) > 0.05 && abs($0.n.y) < 0.95 })
        // the 2D drawings keep the board's boxes
        XCTAssertTrue(build(r, .flat).parts.allSatisfy { $0.faces.count % 6 == 0 })
    }

    /* ---------------- the bathroom, hall panels ---------------- */

    func testBathroomUnitsTakeTheHandleColour() {
        let v = look(piece("sinkV")) { $0.hcol = "gold" }
        let l = looks(v)
        XCTAssertEqual(l["tap"], handleLook("gold"))
        let d = build(v)
        // the white ceramic bowl, the tap and the door's handle in gold
        XCTAssertFalse(faces(d, IT_CERAMIC).isEmpty)
        XCTAssertTrue(faces(d, IT_CERAMIC).contains { $0.pts.count == 4 })
        XCTAssertTrue(faces(d, handleLook("gold")).count > faces(build(look(v) { $0.hcol = "" }), handleLook("gold")).count)
        // without a colour the tap is chrome
        let plain = piece("sinkV")
        XCTAssertEqual(looks(plain)["tap"], looks(plain)["chrome"])
        XCTAssertFalse(faces(build(plain), looks(plain)["chrome"]).isEmpty)
        // the 2D drawings keep the plain white box
        XCTAssertTrue(faces(build(v, .flat), IT_CERAMIC).isEmpty)
        XCTAssertFalse(faces(build(v, .flat), l["white"]).isEmpty)
    }

    func testAHallPanelsMirrorAndHooks() {
        let f = look(piece("mirrorP")) { $0.hcol = "black"; $0.mirror = "bronze"; $0.style = "shaker" }
        let l = looks(f)
        let d = build(f)
        // the mirror in its tint, framed in black; the hooks and the shelf's brackets in black too
        XCTAssertNotEqual(l["mirror"], looks(piece("mirrorP"))["mirror"])
        XCTAssertFalse(faces(d, l["mirror"]).isEmpty)
        let black = faces(d, handleLook("black"))
        XCTAssertTrue(black.count > 4 * 6)
        XCTAssertTrue(black.contains { $0.pts.count >= 8 })
        // the panel milled in the fronts' style: more than its one box
        XCTAssertTrue(faces(d, l["front"]).count > 6 * 2)
    }

    /* ---------------- all of them ---------------- */

    func testEveryFaceIsSound() {
        var fs: [Furniture] = []
        for h in ["", "vertical", "tufted", "panels"] { fs.append(look(piece("bed")) { $0.head = h; $0.panel = true; $0.hcol = "chrome" }) }
        fs.append(look(piece("bed", ["bt": 2])) { $0.head = "tufted"; $0.legs = true })
        fs.append(look(piece("bed", ["bt": 1])) { $0.style = "shaker"; $0.hcol = "gold" })
        fs += [piece("bunk"), piece("loft"), piece("bed")]
        fs.append(opt(look(piece("dining")) { $0.hcol = "black" }) { $0.round = true; $0.top = "wt"; $0.legs = "frame" })
        fs.append(opt(piece("coffee")) { $0.legs = "metal4" })
        fs.append(look(piece("bar")) { $0.style = "fluted"; $0.hcol = "brass" })
        fs.append(look(piece("mirrorP")) { $0.style = "fluted"; $0.hcol = "gold" })
        fs.append(look(piece("sinkV")) { $0.hcol = "black" })
        fs.append(piece("vanity"))
        for f in fs {
            for q in [Quality3.high, .low] {
                let shut = build(f, q)
                let open = build(f, q, open: Set(shut.keys))
                XCTAssertEqual(shut.parts.count, open.parts.count, f.name)
                for d in [shut, open] {
                    for p in d.parts {
                        for fc in p.faces {
                            XCTAssertTrue(fc.pts.count >= 3, f.name)
                            XCTAssertTrue(abs(fc.n.len - 1) < 1e-6, f.name)
                            XCTAssertTrue(abs((fc.grain ?? V3(0, 0, 0)).dot(fc.n)) < 1e-6, f.name)
                            XCTAssertTrue(fc.pts.allSatisfy { abs(($0 - fc.pts[0]).dot(fc.n)) < 1e-9 }, f.name)
                            XCTAssertTrue(fc.pts.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, f.name)
                        }
                    }
                }
            }
            let flat = build(f, .flat)
            XCTAssertTrue(flat.parts.allSatisfy { $0.faces.count % 6 == 0 }, f.name)
            XCTAssertTrue(flat.parts.allSatisfy { $0.faces.allSatisfy { $0.pts.count == 4 } }, f.name)
        }
    }

    func testTheGalleryCardShowsTheBed() {
        let f = look(piece("bed")) { $0.head = "tufted"; $0.panel = true; $0.fabric = "navy" }
        let s = cardShell(f, ws, MAT_PRESETS, .high)
        let fab = gkFabricLook(f)
        XCTAssertTrue(s.parts.contains { $0.look == fab && !$0.faces.isEmpty })
        // the card's camera fits round the panel too (the 2D scene it aims by has the panel's boxes)
        let ext = pieceScene(f, ws, MAT_PRESETS).ext
        XCTAssertTrue((ext.map(\.y).max() ?? 0) >= PANEL_Y1 / 1000)
    }
}
