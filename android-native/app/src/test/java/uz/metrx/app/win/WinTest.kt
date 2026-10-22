package uz.metrx.app.win

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlumbOrder

/**
 * The windows-and-doors app on a living room 4 × 3,5 × 2,7 m with brick walls 380 thick: two windows on wall C
 * (1300 × 1400 at 600 and 2000 × 1400 at 1900 from C's start, sills 850) and a door on wall A (800 × 2100 at 300).
 */
class WinTest {
    private val room = Room("r", "w", "Mehmonxona", dims = mapOf("A" to Dim(4000), "B" to Dim(3500), "H" to Dim(2700), "T" to Dim(380)),
        openings = listOf(Opening("w1", "window", "C", 1300, 1400, 600, 850), Opening("w2", "window", "C", 2000, 1400, 1900, 850),
            Opening("d1", "door", "A", 800, 2100, 300)))
    private fun project(items: List<WinItem> = emptyList(), plumb: PlumbOrder = PlumbOrder(), r: Room = room) =
        Project("p", "Test", floors = listOf(Workspace("w", "Mehmonxona", "room")), rooms = listOf(r), industry = "win", win = WinOrder(items), plumb = plumb)
    private fun c(p: Project) = ctxOf(p, "r", true)!!
    private fun two(id: String = "i2", w: Int = 1300, h: Int = 1400) = newItem(id, wkind("w2"), w, h)

    @Test fun productSizeIsTheOpeningLessTheGaps() {
        val p = project()
        val cx = c(p)
        assertEquals(380, cx.T)
        // a window: the gap all round; a door: none at the floor
        val win = fillOpening("a", wkind("w2"), cx, cx.opening("w1")!!, 20)
        assertEquals(1260, win.w); assertEquals(1360, win.h)
        val door = fillOpening("b", wkind("dint"), cx, cx.opening("d1")!!, 15)
        assertEquals(770, door.w); assertEquals(2085, door.h)
        assertEquals(1260 to 1360, sizeFor(1300, 1400, "window", 20))
        // the window's sashes stretched in proportion, a sill for the brick wall's reveal and a drip
        assertEquals(listOf(630, 630), win.cols.map { it.w })
        assertEquals(1360, win.cols[0].rows[0].h)
        assertEquals(155, revealOf(380, frameDepth(win)))
        assertEquals(250, win.sill); assertTrue(win.drip)
        // it stands centred in its opening
        val pl = placed(cx, win)!!
        assertEquals(620.0, pl.a0, 1e-9); assertEquals(870.0, pl.z0, 1e-9)
        val pd = placed(cx, door)!!
        assertEquals(315.0, pd.a0, 1e-9); assertEquals(0.0, pd.z0, 1e-9)
        // refitted after the opening changed, the gap kept
        val r2 = refit(win, 1500, 1400, "window")
        assertEquals(1460, r2.w); assertEquals(listOf(730, 730), r2.cols.map { it.w })
        // a door type fills doors, a window type windows, a balcony block either
        assertEquals(listOf("w1", "w2"), openingsFor(cx, "w3").map { it.id })
        assertEquals(listOf("d1"), openingsFor(cx, "dent").map { it.id })
        assertEquals(3, openingsFor(cx, "balc").size)
    }

    @Test fun sashSplitGeometry() {
        val it = two()
        val ss = sashesOf(it)
        assertEquals(2, ss.size)
        // a 60 frame round the outside, an 80 mullion on the 650 axis
        assertEquals(WRect(60.0, 60.0, 610.0, 1340.0), ss[0].r)
        assertEquals(WRect(690.0, 60.0, 1240.0, 1340.0), ss[1].r)
        assertEquals("fix", ss[0].t); assertEquals("tt", ss[1].t); assertEquals("R", ss[1].cell.hinge)
        val bars = barsOf(it)
        assertEquals(1, bars.size); assertTrue(bars[0].vertical); assertEquals(1280.0, bars[0].len, 1e-9)
        // a transom in the fixed sash: the fanlight on top is fixed, the lower part keeps its type
        val t = splitRow(setCell(it, 0, 0) { c -> c.copy(t = "turn", hinge = "L") }, 0, 0)
        assertEquals(listOf(700, 700), t.cols[0].rows.map { r -> r.h })
        assertEquals(listOf("fix", "turn"), t.cols[0].rows.map { r -> r.t })
        val tb = barsOf(t).first { b -> !b.vertical }
        assertEquals(700.0, tb.y0, 1e-9); assertEquals(60.0, tb.x0, 1e-9); assertEquals(610.0, tb.x1, 1e-9)
        // the transom dragged: 500 down from the top
        val moved = moveTransom(t, 0, 0, 500)
        assertEquals(listOf(500, 900), moved.cols[0].rows.map { r -> r.h })
        // a third column, the mullion dragged, then typed
        val three = splitCol(it, 1)
        assertEquals(listOf(650, 325, 325), three.cols.map { c -> c.w })
        assertEquals(listOf(650, 400, 250), moveMullion(three, 1, 1050).cols.map { c -> c.w })
        assertEquals(listOf(650, 450, 200), setColW(three, 2, 200).cols.map { c -> c.w })
        // and taken away again
        assertEquals(listOf(650, 650), mergeAt(three, 2, 0).cols.map { c -> c.w })
        assertEquals(1, mergeAt(moved, 0, 1).cols[0].rows.size)
    }

    @Test fun sashLimitsWarn() {
        // a turning sash 1000 wide, a tilt-and-turn one too big, a PVC slider too wide (aluminium may), a door's sash high
        val wide = WinItem("a", "w1", w = 1120, h = 1400, cols = listOf(WCol(1120, listOf(WCell(1400, "turn")))))
        assertEquals(listOf("dw.w.wide"), sashWarnings(wide, null).map { it.key })
        val tt = WinItem("b", "w1", w = 970, h = 1700, cols = listOf(WCol(970, listOf(WCell(1700, "tt")))))
        assertEquals(listOf("dw.w.area"), sashWarnings(tt, null).map { it.key })
        val high = WinItem("c", "w1", w = 800, h = 1760, cols = listOf(WCol(800, listOf(WCell(1760, "turn")))))
        assertEquals(listOf("dw.w.high"), sashWarnings(high, null).map { it.key })
        val slide = WinItem("d", "wsl", w = 1720, h = 1400, cols = listOf(WCol(1720, listOf(WCell(1400, "slide")))))
        assertEquals(listOf("dw.w.wide"), sashWarnings(slide, null).map { it.key })
        assertTrue(sashWarnings(slide.copy(profile = "alu", chambers = 3), null).isEmpty())
        val narrow = WinItem("e", "w1", w = 400, h = 1400, cols = listOf(WCol(400, listOf(WCell(1400, "tt")))))
        assertEquals(listOf("dw.w.narrow"), sashWarnings(narrow, null).map { it.key })
        // a balcony block's door sash 2100 high is a door's, fine; the gallery's types warn about nothing
        assertTrue(sashWarnings(newItem("f", wkind("balc")), null).isEmpty())
        W_KINDS.forEach { k -> assertTrue(k.id, sashWarnings(newItem("g", k), null).isEmpty()) }
        // a fixed sash has no limits
        assertTrue(sashWarnings(WinItem("h", "w1", w = 3000, h = 2500, cols = listOf(WCol(3000, listOf(WCell(2500))))), null).isEmpty())
        // heavy: a tilting fanlight 1500 × 1000 with a two-chamber unit (44 kg); with a one-chamber one it is light enough
        val heavy = WinItem("i", "w1", w = 1620, h = 1120, cols = listOf(WCol(1620, listOf(WCell(1120, "tilt")))))
        assertEquals(listOf("dw.w.heavy"), sashWarnings(heavy, null).map { it.key })
        assertEquals(44.5, sashKg(heavy, sashesOf(heavy)[0]), .5)
        assertTrue(sashWarnings(heavy.copy(glass = 1), null).isEmpty())
    }

    @Test fun partsOfATwoSashWindow() {
        // 1300 × 1400 PVC: a fixed sash and a tilt-and-turn one, a two-chamber unit
        val it = two()
        val pt = partsOf(it, 155)
        assertEquals(5.4, pt.frameM, 1e-9)
        assertEquals(1.28, pt.mullM, 1e-9)
        assertEquals(3.66, pt.sashM, 1e-9)
        // fixed: its cell less the 8 mm seats; the opening one inside its 75 profile
        assertEquals(534.0 * 1264 / 1e6 + 416.0 * 1146 / 1e6, pt.glassM2, 1e-9)
        assertEquals(mapOf("tt" to 1), pt.hw)
        assertEquals(1, pt.handles); assertEquals(0, pt.nets)
        assertEquals(1.82, pt.areaM2, 1e-9)
        assertEquals(0.0, pt.panelM2, 1e-9)
        // the extras: a sill with its ears, a drip, reveals round three sides 155 deep, a net on the opening sash
        val ex = partsOf(it.copy(sill = 250, drip = true, reveals = true, net = true), 155)
        assertEquals(1.4, ex.sillM, 1e-9)
        assertEquals(1.35, ex.dripM, 1e-9)
        assertEquals((2 * 1400 + 1300) * 155 / 1e6, ex.revealM2, 1e-9)
        assertEquals(1, ex.nets)
        // a balcony block's panel
        val b = partsOf(newItem("b", wkind("balc")), 155)
        assertTrue(b.panelM2 > 0.8)
        // a door: its area and one lock-and-hinges set
        val d = partsOf(newItem("d", wkind("dint")), 0)
        assertEquals(1.6, d.doorM2, 1e-9); assertEquals(mapOf("door" to 1), d.hw)
    }

    @Test fun doorSwingAndBlockedSashes() {
        // a door hinged on the left opening in, a second door round the corner on wall D, close to it
        val r = room.copy(openings = room.openings + Opening("d2", "door", "D", 800, 2100, 2700))
        val door = fillOpening("dd", wkind("dint"), c(project(r = r)), r.openings.first { it.id == "d1" }, 15)
        val p = project(listOf(door), r = r)
        val cx = c(p)
        val sw = doorSweep(placed(cx, door)!!)!!
        // the leaf 690 wide from its hinge at 355 along wall A, into the room
        val xs = sw.poly.map { it.x }; val ys = sw.poly.map { it.y }
        assertEquals(355.0, xs.min(), 1e-6); assertEquals(1045.0, xs.max(), 1e-6)
        assertEquals(0.0, ys.min(), 1e-6); assertEquals(690.0, ys.max(), 1e-6)
        assertTrue(warningsOf(p, listOf(cx), true).any { it.key == "dw.w.doors" })
        // opening out it sweeps nothing here, hinged on the right it goes the other way
        assertNull(doorSweep(placed(cx, door.copy(swing = "out"))!!))
        assertFalse(warningsOf(project(listOf(door.copy(swing = "out")), r = r), listOf(cx), true).any { it.key == "dw.w.doors" })
        val right = doorSweep(placed(cx, door.copy(hinge = "R"))!!)!!
        assertEquals(355.0, right.poly.minOf { it.x }, 1e-6)
        // a boiler hung on wall C in front of a window's turning sash: blocked; a radiator under the sill is not
        val win = setCell(fillOpening("ww", wkind("w2"), cx, cx.opening("w1")!!, 20), 1, 0) { s -> s.copy(t = "turn", hinge = "L") }
        val boiler = PlFix("gb1", "gb", "r", "C", 1500)
        val rad = PlFix("rad1", "rad", "r", "C", 1500)
        val pw = project(listOf(win), PlumbOrder(fixes = listOf(boiler)))
        val ws = warningsOf(pw, listOf(c(pw)), true)
        assertEquals(listOf("dw.w.blocked"), ws.map { it.key })
        assertEquals("~dw.ob.fix", ws[0].vars["o"])
        val pr = project(listOf(win), PlumbOrder(fixes = listOf(rad)))
        assertTrue(warningsOf(pr, listOf(c(pr)), true).isEmpty())
        // a fixed window sweeps nothing
        val fixed = win.copy(cols = listOf(WCol(win.w, listOf(WCell(win.h)))))
        assertTrue(sashSweeps(placed(cx, fixed)!!).isEmpty())
    }

    @Test fun sillAgainstTheRevealAndOtherFits() {
        val r = room.copy(dims = room.dims + ("T" to Dim(200)))
        val p0 = project(r = r)
        val cx = c(p0)
        val win = fillOpening("a", wkind("w2"), cx, cx.opening("w1")!!, 20)
        // a 200 wall: the reveal 65, the usual sill 150
        assertEquals(150, win.sill)
        val ok = project(listOf(win), r = r)
        assertTrue(warningsOf(ok, listOf(c(ok)), true).isEmpty())
        val deep = project(listOf(win.copy(sill = 250)), r = r)
        val w = warningsOf(deep, listOf(c(deep)), true)
        assertEquals(listOf("dw.w.sill"), w.map { it.key })
        assertEquals("19", w[0].vars["m"])
        // bigger than its opening; an opening taken away
        val big = project(listOf(win.copy(w = 1350)), r = r)
        assertEquals(listOf("dw.w.big"), warningsOf(big, listOf(c(big)), true).map { it.key })
        val gone = project(listOf(win.copy(opening = "zz")), r = r)
        assertEquals(listOf("dw.w.gone"), warningsOf(gone, listOf(c(gone)), true).map { it.key })
    }

    @Test fun productWithoutARoom() {
        val free = newItem("f", wkind("w3"), 1800, 1500).copy(qty = 3, name = "Oshxona")
        assertFalse(free.inRoom); assertFalse(free.drip)
        val p = project(listOf(free))
        val cs = ctxs(p, true)
        assertEquals(listOf("r", "free:f"), cs.map { it.id })
        val fc = cs[1]
        assertEquals(FREE_T, fc.T)
        val o = fc.room.openings.single()
        assertEquals(1840, o.w); assertEquals(1540, o.h); assertEquals(850, o.sill); assertEquals("window", o.type)
        val pl = placed(fc, free)!!
        assertEquals(o.off + 20.0, pl.a0, 1e-9); assertEquals(870.0, pl.z0, 1e-9)
        assertEquals(listOf(free), itemsIn(p, fc))
        // three alike: three times the parts
        val one = partsOf(free, revealOf(FREE_T, frameDepth(free)))
        val n = countOf(p)
        assertEquals(3, n.windows)
        assertEquals(one.frameM * 3, n.sys["pvc"]!!.frameM, 1e-9)
        assertEquals(2 * 3, n.handles)
        // a door without a room stands on the floor
        val fd = newItem("g", wkind("dent"))
        val fdo = freeCtx(fd)!!.room.openings.single()
        assertEquals("door", fdo.type); assertEquals(0, fdo.sill); assertEquals(940, fdo.w); assertEquals(2070, fdo.h)
    }

    @Test fun estimateRows() {
        val t = WinPrices()
        val win = two().copy(sill = 250, drip = true, net = true, colIn = "goak")
        val door = newItem("d", wkind("dint"), roomId = "r", opening = "d1")
        val p = project(listOf(win.copy(roomId = "r", opening = "w1"), door))
        val r = winRows(p, t) { k, v -> k + v.entries.joinToString("") { "|${it.key}=${it.value}" } }
        val m = r.mats.associateBy { it.id }
        assertEquals("5.4", m["t-frame-pvc"]!!.qty); assertEquals("45000", m["t-frame-pvc"]!!.price)
        assertEquals("3.7", m["t-sash-pvc"]!!.qty)
        assertEquals("1.3", m["t-mull-pvc"]!!.qty)
        assertEquals("1", m["t-hw-pvc-tt"]!!.qty); assertEquals("220000", m["t-hw-pvc-tt"]!!.price)
        assertEquals("1.16", m["t-glass2"]!!.qty)
        assertNull(m["t-glass1"])
        // laminated inside only: the profile's metres once
        assertEquals("10.4", m["t-lam"]!!.qty)
        assertEquals("1.4", m["t-sill"]!!.qty); assertEquals("1.4", m["t-drip"]!!.qty)
        assertEquals("1", m["t-net"]!!.qty); assertEquals("1", m["t-handle"]!!.qty)
        assertEquals("1.6", m["t-door-dint"]!!.qty); assertEquals("1", m["t-doorHw"]!!.qty)
        assertTrue(m["t-door-dint"]!!.name.contains("k=~dw.k.dint"))
        val l = r.labor.associateBy { it.id }
        assertEquals("327600", l["t-lWin-pvc"]!!.amount)
        assertEquals("300000", l["t-lDoor"]!!.amount)
        assertEquals("42000", l["t-lSill"]!!.amount)
        assertTrue(r.mats.all { it.id.startsWith("t-") } && r.labor.all { it.id.startsWith("t-") })
        // one product's price is its own lines
        assertTrue(itemCost(win, 155, t) > 0)
        assertEquals(total(r), itemCost(win, 155, t) + itemCost(door, revealOf(380, DOOR_DEPTH), t), 2.0)
        // an aluminium slider goes in its own system's lines
        val al = newItem("s", wkind("wsl"))
        val ra = rowsFor(listOf(al to 100), t) { k, _ -> k }
        assertNotNull(ra.mats.firstOrNull { it.id == "t-frame-alu" })
        assertEquals("2", ra.mats.first { it.id == "t-hw-alu-slide" }.qty)
        assertNull(ra.mats.firstOrNull { it.id == "t-lam" })
    }
}
