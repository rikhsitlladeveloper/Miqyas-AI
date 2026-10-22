import XCTest
@testable import METRX

/// The windows-and-doors app on a living room 4 × 3,5 × 2,7 m with brick walls 380 thick: two windows on wall C
/// (1300 × 1400 at 600 and 2000 × 1400 at 1900 from C's start, sills 850) and a door on wall A (800 × 2100 at 300). The
/// same cases and numbers as the Android unit test WinTest.
final class WinTests: XCTestCase {
    private var room: Room {
        var r = Room(id: "r", floorId: "w", name: "Mehmonxona")
        r.dims = ["A": Dim(v: 4000), "B": Dim(v: 3500), "H": Dim(v: 2700), "T": Dim(v: 380)]
        r.openings = [
            Opening(id: "w1", type: "window", wall: "C", w: 1300, h: 1400, off: 600, sill: 850),
            Opening(id: "w2", type: "window", wall: "C", w: 2000, h: 1400, off: 1900, sill: 850),
            Opening(id: "d1", type: "door", wall: "A", w: 800, h: 2100, off: 300)
        ]
        return r
    }

    private func project(_ items: [WinItem] = [], plumb: PlumbOrder = PlumbOrder(), r: Room? = nil) -> Project {
        var p = Project(id: "p", name: "Test")
        p.floors = [Workspace(id: "w", name: "Mehmonxona", type: "room")]
        p.rooms = [r ?? room]
        p.industry = "win"
        p.win = WinOrder(items: items)
        p.plumb = plumb
        return p
    }

    private func c(_ p: Project) -> WCtx { wCtxOf(p, "r", true)! }

    private func two(_ id: String = "i2", _ w: Int = 1300, _ h: Int = 1400) -> WinItem { wNewItem(id, wkind("w2"), w, h) }

    private func item(_ id: String, _ kind: String, _ w: Int, _ h: Int, _ t: String) -> WinItem {
        WinItem(id: id, kind: kind, w: w, h: h, cols: [WCol(w: w, rows: [WCell(h: h, t: t)])])
    }

    func testProductSizeIsTheOpeningLessTheGaps() {
        let p = project()
        let cx = c(p)
        XCTAssertEqual(cx.T, 380)
        // a window: the gap all round; a door: none at the floor
        let win = wFillOpening("a", wkind("w2"), cx, cx.opening("w1")!, 20)
        XCTAssertEqual(win.w, 1260); XCTAssertEqual(win.h, 1360)
        let door = wFillOpening("b", wkind("dint"), cx, cx.opening("d1")!, 15)
        XCTAssertEqual(door.w, 770); XCTAssertEqual(door.h, 2085)
        let s = wSizeFor(1300, 1400, "window", 20)
        XCTAssertEqual(s.0, 1260); XCTAssertEqual(s.1, 1360)
        // the window's sashes stretched in proportion, a sill for the brick wall's reveal and a drip
        XCTAssertEqual(win.cols.map(\.w), [630, 630])
        XCTAssertEqual(win.cols[0].rows[0].h, 1360)
        XCTAssertEqual(wRevealOf(380, wFrameDepth(win)), 155)
        XCTAssertEqual(win.sill, 250); XCTAssertTrue(win.drip)
        // it stands centred in its opening
        let pl = wPlaced(cx, win)!
        XCTAssertEqual(pl.a0, 620.0, accuracy: 1e-9); XCTAssertEqual(pl.z0, 870.0, accuracy: 1e-9)
        let pd = wPlaced(cx, door)!
        XCTAssertEqual(pd.a0, 315.0, accuracy: 1e-9); XCTAssertEqual(pd.z0, 0.0, accuracy: 1e-9)
        // refitted after the opening changed, the gap kept
        let r2 = wRefit(win, 1500, 1400, "window")
        XCTAssertEqual(r2.w, 1460); XCTAssertEqual(r2.cols.map(\.w), [730, 730])
        // a door type fills doors, a window type windows, a balcony block either
        XCTAssertEqual(wOpeningsFor(cx, "w3").map(\.id), ["w1", "w2"])
        XCTAssertEqual(wOpeningsFor(cx, "dent").map(\.id), ["d1"])
        XCTAssertEqual(wOpeningsFor(cx, "balc").count, 3)
    }

    func testSashSplitGeometry() {
        let it = two()
        let ss = wSashesOf(it)
        XCTAssertEqual(ss.count, 2)
        // a 60 frame round the outside, an 80 mullion on the 650 axis
        XCTAssertEqual(ss[0].r, WRect(x0: 60, y0: 60, x1: 610, y1: 1340))
        XCTAssertEqual(ss[1].r, WRect(x0: 690, y0: 60, x1: 1240, y1: 1340))
        XCTAssertEqual(ss[0].t, "fix"); XCTAssertEqual(ss[1].t, "tt"); XCTAssertEqual(ss[1].cell.hinge, "R")
        let bars = wBarsOf(it)
        XCTAssertEqual(bars.count, 1); XCTAssertTrue(bars[0].vertical); XCTAssertEqual(bars[0].len, 1280.0, accuracy: 1e-9)
        // a transom in the fixed sash: the fanlight on top is fixed, the lower part keeps its type
        let turned = wSetCell(it, 0, 0) { c in
            var x = c
            x.t = "turn"; x.hinge = "L"
            return x
        }
        let t = wSplitRow(turned, 0, 0)
        XCTAssertEqual(t.cols[0].rows.map(\.h), [700, 700])
        XCTAssertEqual(t.cols[0].rows.map(\.t), ["fix", "turn"])
        let tb = wBarsOf(t).first { !$0.vertical }!
        XCTAssertEqual(tb.y0, 700.0, accuracy: 1e-9); XCTAssertEqual(tb.x0, 60.0, accuracy: 1e-9); XCTAssertEqual(tb.x1, 610.0, accuracy: 1e-9)
        // the transom dragged: 500 down from the top
        let moved = wMoveTransom(t, 0, 0, 500)
        XCTAssertEqual(moved.cols[0].rows.map(\.h), [500, 900])
        // a third column, the mullion dragged, then typed
        let three = wSplitCol(it, 1)
        XCTAssertEqual(three.cols.map(\.w), [650, 325, 325])
        XCTAssertEqual(wMoveMullion(three, 1, 1050).cols.map(\.w), [650, 400, 250])
        XCTAssertEqual(wSetColW(three, 2, 200).cols.map(\.w), [650, 450, 200])
        // and taken away again
        XCTAssertEqual(wMergeAt(three, 2, 0).cols.map(\.w), [650, 650])
        XCTAssertEqual(wMergeAt(moved, 0, 1).cols[0].rows.count, 1)
    }

    func testSashLimitsWarn() {
        // a turning sash 1000 wide, a tilt-and-turn one too big, a PVC slider too wide (aluminium may), a door's sash high
        let wide = item("a", "w1", 1120, 1400, "turn")
        XCTAssertEqual(wSashWarnings(wide, nil).map(\.key), ["dw.w.wide"])
        let tt = item("b", "w1", 970, 1700, "tt")
        XCTAssertEqual(wSashWarnings(tt, nil).map(\.key), ["dw.w.area"])
        let high = item("c", "w1", 800, 1760, "turn")
        XCTAssertEqual(wSashWarnings(high, nil).map(\.key), ["dw.w.high"])
        let slide = item("d", "wsl", 1720, 1400, "slide")
        XCTAssertEqual(wSashWarnings(slide, nil).map(\.key), ["dw.w.wide"])
        var alu = slide
        alu.profile = "alu"; alu.chambers = 3
        XCTAssertTrue(wSashWarnings(alu, nil).isEmpty)
        let narrow = item("e", "w1", 400, 1400, "tt")
        XCTAssertEqual(wSashWarnings(narrow, nil).map(\.key), ["dw.w.narrow"])
        // a balcony block's door sash 2100 high is a door's, fine; the gallery's types warn about nothing
        XCTAssertTrue(wSashWarnings(wNewItem("f", wkind("balc")), nil).isEmpty)
        for k in W_KINDS { XCTAssertTrue(wSashWarnings(wNewItem("g", k), nil).isEmpty, k.id) }
        // a fixed sash has no limits
        XCTAssertTrue(wSashWarnings(item("h", "w1", 3000, 2500, "fix"), nil).isEmpty)
        // heavy: a tilting fanlight 1500 × 1000 with a two-chamber unit (44 kg); with a one-chamber one it is light enough
        let heavy = item("i", "w1", 1620, 1120, "tilt")
        XCTAssertEqual(wSashWarnings(heavy, nil).map(\.key), ["dw.w.heavy"])
        XCTAssertEqual(wSashKg(heavy, wSashesOf(heavy)[0]), 44.5, accuracy: 0.5)
        var light = heavy
        light.glass = 1
        XCTAssertTrue(wSashWarnings(light, nil).isEmpty)
    }

    func testPartsOfATwoSashWindow() {
        // 1300 × 1400 PVC: a fixed sash and a tilt-and-turn one, a two-chamber unit
        let it = two()
        let pt = wPartsOf(it, 155)
        XCTAssertEqual(pt.frameM, 5.4, accuracy: 1e-9)
        XCTAssertEqual(pt.mullM, 1.28, accuracy: 1e-9)
        XCTAssertEqual(pt.sashM, 3.66, accuracy: 1e-9)
        // fixed: its cell less the 8 mm seats; the opening one inside its 75 profile
        let glass: Double = 534.0 * 1264 / 1e6 + 416.0 * 1146 / 1e6
        XCTAssertEqual(pt.glassM2, glass, accuracy: 1e-9)
        XCTAssertEqual(pt.hw, ["tt": 1])
        XCTAssertEqual(pt.handles, 1); XCTAssertEqual(pt.nets, 0)
        XCTAssertEqual(pt.areaM2, 1.82, accuracy: 1e-9)
        XCTAssertEqual(pt.panelM2, 0.0, accuracy: 1e-9)
        // the extras: a sill with its ears, a drip, reveals round three sides 155 deep, a net on the opening sash
        var withEx = it
        withEx.sill = 250; withEx.drip = true; withEx.reveals = true; withEx.net = true
        let ex = wPartsOf(withEx, 155)
        XCTAssertEqual(ex.sillM, 1.4, accuracy: 1e-9)
        XCTAssertEqual(ex.dripM, 1.35, accuracy: 1e-9)
        let rev: Double = Double(2 * 1400 + 1300) * 155 / 1e6
        XCTAssertEqual(ex.revealM2, rev, accuracy: 1e-9)
        XCTAssertEqual(ex.nets, 1)
        // a balcony block's panel
        let b = wPartsOf(wNewItem("b", wkind("balc")), 155)
        XCTAssertTrue(b.panelM2 > 0.8)
        // a door: its area and one lock-and-hinges set
        let d = wPartsOf(wNewItem("d", wkind("dint")), 0)
        XCTAssertEqual(d.doorM2, 1.6, accuracy: 1e-9); XCTAssertEqual(d.hw, ["door": 1])
    }

    func testDoorSwingAndBlockedSashes() {
        // a door hinged on the left opening in, a second door round the corner on wall D, close to it
        var r = room
        r.openings.append(Opening(id: "d2", type: "door", wall: "D", w: 800, h: 2100, off: 2700))
        let door = wFillOpening("dd", wkind("dint"), c(project(r: r)), r.openings.first { $0.id == "d1" }!, 15)
        let p = project([door], r: r)
        let cx = c(p)
        let sw = wDoorSweep(wPlaced(cx, door)!)!
        // the leaf 690 wide from its hinge at 355 along wall A, into the room
        let xs = sw.poly.map(\.x), ys = sw.poly.map(\.y)
        XCTAssertEqual(xs.min()!, 355.0, accuracy: 1e-6); XCTAssertEqual(xs.max()!, 1045.0, accuracy: 1e-6)
        XCTAssertEqual(ys.min()!, 0.0, accuracy: 1e-6); XCTAssertEqual(ys.max()!, 690.0, accuracy: 1e-6)
        XCTAssertTrue(wWarningsOf(p, [cx], true).contains { $0.key == "dw.w.doors" })
        // opening out it sweeps nothing here, hinged on the right it goes the other way
        var out = door
        out.swing = "out"
        XCTAssertNil(wDoorSweep(wPlaced(cx, out)!))
        XCTAssertFalse(wWarningsOf(project([out], r: r), [cx], true).contains { $0.key == "dw.w.doors" })
        var right = door
        right.hinge = "R"
        let rs = wDoorSweep(wPlaced(cx, right)!)!
        XCTAssertEqual(rs.poly.map(\.x).min()!, 355.0, accuracy: 1e-6)
        // a boiler hung on wall C in front of a window's turning sash: blocked; a radiator under the sill is not
        let filled = wFillOpening("ww", wkind("w2"), cx, cx.opening("w1")!, 20)
        let win = wSetCell(filled, 1, 0) { s in
            var x = s
            x.t = "turn"; x.hinge = "L"
            return x
        }
        let boiler = PlFix(id: "gb1", t: "gb", roomId: "r", wall: "C", off: 1500)
        let rad = PlFix(id: "rad1", t: "rad", roomId: "r", wall: "C", off: 1500)
        let pw = project([win], plumb: PlumbOrder(fixes: [boiler]))
        let ws = wWarningsOf(pw, [c(pw)], true)
        XCTAssertEqual(ws.map(\.key), ["dw.w.blocked"])
        XCTAssertEqual(ws[0].vars["o"], "~dw.ob.fix")
        let pr = project([win], plumb: PlumbOrder(fixes: [rad]))
        XCTAssertTrue(wWarningsOf(pr, [c(pr)], true).isEmpty)
        // a fixed window sweeps nothing
        var fixed = win
        fixed.cols = [WCol(w: win.w, rows: [WCell(h: win.h)])]
        XCTAssertTrue(wSashSweeps(wPlaced(cx, fixed)!).isEmpty)
    }

    func testSillAgainstTheRevealAndOtherFits() {
        var r = room
        r.dims["T"] = Dim(v: 200)
        let p0 = project(r: r)
        let cx = c(p0)
        let win = wFillOpening("a", wkind("w2"), cx, cx.opening("w1")!, 20)
        // a 200 wall: the reveal 65, the usual sill 150
        XCTAssertEqual(win.sill, 150)
        let ok = project([win], r: r)
        XCTAssertTrue(wWarningsOf(ok, [c(ok)], true).isEmpty)
        var deepW = win
        deepW.sill = 250
        let deep = project([deepW], r: r)
        let w = wWarningsOf(deep, [c(deep)], true)
        XCTAssertEqual(w.map(\.key), ["dw.w.sill"])
        XCTAssertEqual(w[0].vars["m"], "19")
        // bigger than its opening; an opening taken away
        var bigW = win
        bigW.w = 1350
        let big = project([bigW], r: r)
        XCTAssertEqual(wWarningsOf(big, [c(big)], true).map(\.key), ["dw.w.big"])
        var goneW = win
        goneW.opening = "zz"
        let gone = project([goneW], r: r)
        XCTAssertEqual(wWarningsOf(gone, [c(gone)], true).map(\.key), ["dw.w.gone"])
    }

    func testProductWithoutARoom() {
        var free = wNewItem("f", wkind("w3"), 1800, 1500)
        free.qty = 3; free.name = "Oshxona"
        XCTAssertFalse(free.inRoom); XCTAssertFalse(free.drip)
        let p = project([free])
        let cs = wCtxs(p, true)
        XCTAssertEqual(cs.map(\.id), ["r", "free:f"])
        let fc = cs[1]
        XCTAssertEqual(fc.T, W_FREE_T)
        XCTAssertEqual(fc.room.openings.count, 1)
        let o = fc.room.openings[0]
        XCTAssertEqual(o.w, 1840); XCTAssertEqual(o.h, 1540); XCTAssertEqual(o.sill, 850); XCTAssertEqual(o.type, "window")
        let pl = wPlaced(fc, free)!
        XCTAssertEqual(pl.a0, Double(o.off) + 20.0, accuracy: 1e-9); XCTAssertEqual(pl.z0, 870.0, accuracy: 1e-9)
        XCTAssertEqual(wItemsIn(p, fc), [free])
        // three alike: three times the parts
        let one = wPartsOf(free, wRevealOf(W_FREE_T, wFrameDepth(free)))
        let n = wCountOf(p)
        XCTAssertEqual(n.windows, 3)
        XCTAssertEqual(n.sys["pvc"]!.frameM, one.frameM * 3, accuracy: 1e-9)
        XCTAssertEqual(n.handles, 2 * 3)
        // a door without a room stands on the floor
        let fd = wNewItem("g", wkind("dent"))
        let fdo = wFreeCtx(fd)!.room.openings[0]
        XCTAssertEqual(fdo.type, "door"); XCTAssertEqual(fdo.sill, 0); XCTAssertEqual(fdo.w, 940); XCTAssertEqual(fdo.h, 2070)
    }

    func testEstimateRows() {
        let t = WinPrices()
        var win = two()
        win.sill = 250; win.drip = true; win.net = true; win.colIn = "goak"
        let door = wNewItem("d", wkind("dint"), roomId: "r", opening: "d1")
        var placedWin = win
        placedWin.roomId = "r"; placedWin.opening = "w1"
        let p = project([placedWin, door])
        let r = winRows(p, t) { k, v in k + v.keys.sorted().map { "|" + $0 + "=" + (v[$0] ?? "") }.joined() }
        var m: [String: Row] = [:]
        for x in r.mats { m[x.id] = x }
        XCTAssertEqual(m["t-frame-pvc"]?.qty, "5.4"); XCTAssertEqual(m["t-frame-pvc"]?.price, "45000")
        XCTAssertEqual(m["t-sash-pvc"]?.qty, "3.7")
        XCTAssertEqual(m["t-mull-pvc"]?.qty, "1.3")
        XCTAssertEqual(m["t-hw-pvc-tt"]?.qty, "1"); XCTAssertEqual(m["t-hw-pvc-tt"]?.price, "220000")
        XCTAssertEqual(m["t-glass2"]?.qty, "1.16")
        XCTAssertNil(m["t-glass1"])
        // laminated inside only: the profile's metres once
        XCTAssertEqual(m["t-lam"]?.qty, "10.4")
        XCTAssertEqual(m["t-sill"]?.qty, "1.4"); XCTAssertEqual(m["t-drip"]?.qty, "1.4")
        XCTAssertEqual(m["t-net"]?.qty, "1"); XCTAssertEqual(m["t-handle"]?.qty, "1")
        XCTAssertEqual(m["t-door-dint"]?.qty, "1.6"); XCTAssertEqual(m["t-doorHw"]?.qty, "1")
        XCTAssertTrue(m["t-door-dint"]?.name.contains("k=~dw.k.dint") == true)
        var l: [String: Row] = [:]
        for x in r.labor { l[x.id] = x }
        XCTAssertEqual(l["t-lWin-pvc"]?.amount, "327600")
        XCTAssertEqual(l["t-lDoor"]?.amount, "300000")
        XCTAssertEqual(l["t-lSill"]?.amount, "42000")
        XCTAssertTrue(r.mats.allSatisfy { $0.id.hasPrefix("t-") } && r.labor.allSatisfy { $0.id.hasPrefix("t-") })
        // one product's price is its own lines
        XCTAssertTrue(wItemCost(win, 155, t) > 0)
        let sum = wItemCost(win, 155, t) + wItemCost(door, wRevealOf(380, W_DOOR_DEPTH), t)
        XCTAssertEqual(wTotal(r), sum, accuracy: 2.0)
        // an aluminium slider goes in its own system's lines
        let al = wNewItem("s", wkind("wsl"))
        let ra = wRowsFor([(al, 100)], t) { k, _ in k }
        XCTAssertNotNil(ra.mats.first { $0.id == "t-frame-alu" })
        XCTAssertEqual(ra.mats.first { $0.id == "t-hw-alu-slide" }?.qty, "2")
        XCTAssertNil(ra.mats.first { $0.id == "t-lam" })
    }
}
