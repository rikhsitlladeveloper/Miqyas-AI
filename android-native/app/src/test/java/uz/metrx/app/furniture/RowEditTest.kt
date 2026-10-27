package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Designer C v2's row rules (founder's decisions, 27 Oct 2026): snaps, absorb, insert, close a gap, copy, move. */
class RowEditTest {
    private fun mod(id: String, w: Int, allowed: List<Int>? = null) = Slot(id, w, SK.MOD, allowed)
    private fun gap(id: String, w: Int) = Slot(id, w, SK.GAP, min = 0)
    private fun fill(id: String, w: Int) = Slot(id, w, SK.FILLER, min = 10)
    private fun end(w: Int) = Slot(END_ID, w, SK.END, min = 0)
    private fun ws(r: List<Slot>) = r.map { it.id to it.w }

    /* ---------------- snapping ---------------- */

    @Test fun snapsToTheFoundersWidths() {
        val s = mod("a", 600)
        val c = candidates(s, 1000)
        assertEquals(listOf(150, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000), c)
        assertEquals(450, snapWidth(470.0, c, false, true, 150, 1000, 600))
        assertEquals(1000, snapWidth(1180.0, c, false, true, 150, 1000, 600))
        // the widest it can get is offered when it is not a snap
        assertTrue(830 in candidates(s, 830))
        // zoomed in: 10 mm steps, a snap within 15 mm still winning
        assertEquals(470, snapWidth(468.0, c, true, true, 150, 1000, 600))
        assertEquals(450, snapWidth(458.0, c, true, true, 150, 1000, 600))
        // an appliance keeps its own widths, even zoomed in
        val dw = Slot("dw", 600, SK.FIXED, listOf(450, 600))
        assertEquals(listOf(450, 600), candidates(dw, 900))
        assertEquals(450, snapWidth(468.0, candidates(dw, 900), true, false, 150, 900, 600))
        assertEquals(720, snapHeight(700.0)); assertEquals(360, snapHeight(300.0)); assertEquals(900, snapHeight(1400.0))
    }

    /* ---------------- absorb ---------------- */

    @Test fun theNearestFillerOrGapTakesTheDifference() {
        val row = listOf(mod("sink", 600), mod("dw", 600), mod("dr", 600), fill("f", 50), mod("c", 500), end(0))
        val r = resize(row, 0, 450)
        assertTrue(r.ok)
        // the filler is 3 away, the free end 5: the filler grows
        assertEquals("f", r.aid); assertEquals(50, r.aw0); assertEquals(200, r.aw1)
        // a filler of 150 or more is a gap now
        assertEquals(SK.GAP, r.row.first { it.id == "f" }.kind)
        assertEquals(listOf(450, 600, 600, 200, 500), r.row.filter { it.kind != SK.END }.map { it.w })
    }

    @Test fun withoutAGapTheNeighbourTakesIt() {
        val row = listOf(mod("a", 600), mod("b", 600), mod("c", 600))
        val r = resize(row, 0, 450)
        assertEquals("b", r.aid); assertEquals(listOf(450, 750, 600), r.row.map { it.w })
        // the last one takes from the one before
        assertEquals("b", resize(row, 2, 700).aid)
        // and no further than the neighbour's 150
        val big = resize(row, 0, 1200)
        assertFalse(big.ok); assertEquals("max", big.why); assertEquals(1050, big.limit)
        assertEquals(1050, maxW(row, 0))
    }

    @Test fun theFreeEndCountsAsAGap() {
        val row = listOf(mod("a", 600), mod("b", 600), end(300))
        val r = resize(row, 1, 900)
        assertEquals(END_ID, r.aid); assertEquals(0, r.row.last().w)
        // a full row's end gives nothing: the neighbour gives way instead
        val full = listOf(mod("a", 600), mod("b", 600), end(0))
        assertEquals("b", resize(full, 0, 700).aid)
        // but what a module gives back goes to the end
        assertEquals(END_ID, resize(full, 1, 450).aid)
    }

    @Test fun anApplianceNeverAbsorbs() {
        val row = listOf(mod("a", 600), Slot("hob", 600, SK.FIXED, listOf(450, 600, 900)), mod("c", 600))
        // a's right neighbour is the hob: nobody to its left, so nobody
        assertFalse(resize(row, 0, 450).ok)
        assertFalse(resize(row, 2, 450).ok)
        assertEquals(-1, absorber(row, 0))
    }

    @Test fun wardrobeSectionsShareWithTheNext() {
        val row = listOf(mod("0", 600), mod("1", 600), mod("2", 600), mod("3", 600))
        val r = resize(row, 1, 800, secs = true)
        assertEquals("2", r.aid); assertEquals(listOf(600, 800, 400, 600), r.row.map { it.w })
        assertEquals("2", resize(row, 3, 500, secs = true).aid)
        assertEquals(listOf(600, 600, 600, 600), equalSplit(2400, 4))
        assertEquals(listOf(790, 790, 790), equalSplit(2370, 3))
        assertEquals(listOf(790, 790, 800), equalSplit(2380, 3))
    }

    /* ---------------- delete, close a gap ---------------- */

    @Test fun deleteLeavesAGapAndYopishClosesIt() {
        val row = listOf(mod("a", 600), mod("b", 600), mod("c", 600), fill("f", 50), Slot("corner", 600, SK.CORNER), end(0))
        val d = deleteToGap(row, 1)
        assertEquals(SK.GAP, d[1].kind); assertEquals(600, d[1].w)
        val c = closeGap(d, 1)
        assertTrue(c.ok)
        // the neighbours close up; the end filler before the corner takes the width (and is a gap now)
        assertEquals(listOf("a", "c", "f", "corner", END_ID), c.row.map { it.id })
        assertEquals(650, c.row[2].w); assertEquals(SK.GAP, c.row[2].kind)
        assertEquals("f" to 650, c.grew)
    }

    @Test fun yopishWithoutAnEndFillerGrowsTheFreeEnd() {
        val row = listOf(mod("a", 600), gap("g", 400), mod("c", 600), end(100))
        val c = closeGap(row, 1)
        assertEquals(listOf("a", "c", END_ID), c.row.map { it.id }); assertEquals(500, c.row.last().w)
        // before a corner a new gap goes in
        val row2 = listOf(mod("a", 600), gap("g", 400), mod("c", 600), Slot("k", 600, SK.CORNER), end(0))
        val c2 = closeGap(row2, 1, "new")
        assertEquals(listOf("a", "c", "new", "k", END_ID), c2.row.map { it.id }); assertEquals(SK.GAP, c2.row[2].kind)
        // a narrow one is a filler
        assertEquals(SK.FILLER, closeGap(listOf(mod("a", 600), gap("g", 100), mod("c", 600), Slot("k", 600, SK.CORNER)), 1, "n").row[2].kind)
        // already at the end
        assertFalse(closeGap(listOf(mod("a", 600), gap("g", 400), Slot("k", 600, SK.CORNER)), 1).ok)
    }

    @Test fun twoGapsSideBySideAreOne() {
        val t = tidy(listOf(mod("a", 600), gap("g", 300), gap("h", 200), mod("b", 600), gap("x", 100), end(50)))
        assertEquals(listOf("a" to 600, "g" to 500, "b" to 600, "x" to 100, END_ID to 50), ws(t))
        assertEquals(listOf("a"), tidy(listOf(mod("a", 600), fill("f", 0))).map { it.id })
    }

    /* ---------------- insert ---------------- */

    @Test fun intoAGap() {
        val row = listOf(mod("a", 600), mod("b", 600), gap("g", 800), end(0))
        val p = insertAt(row, 1300, mod("n", 600), false)
        assertTrue(p.ok); assertEquals("g", p.into)
        // dropped on the gap's left half: it goes left, 200 stays
        assertEquals(listOf("a" to 600, "b" to 600, "n" to 600, "g" to 200, END_ID to 0), ws(p.row))
        // on its right half, right
        assertEquals(listOf("a", "b", "g", "n", END_ID), insertAt(row, 1950, mod("n", 600), false).row.map { it.id })
        // too wide: a module narrower (the largest snap that fits), an appliance not
        val small = listOf(mod("a", 600), gap("g", 470), end(0))
        val q = insertAt(small, 700, mod("n", 600), false)
        assertTrue(q.ok); assertTrue(q.adapted); assertEquals(450, q.w)
        assertEquals(SK.FILLER, q.row.first { it.id == "g" }.kind)
        val r = insertAt(small, 700, Slot("dw", 600, SK.FIXED, listOf(450, 600)), true)
        assertFalse(r.ok); assertEquals("gapSmall", r.why)
    }

    @Test fun intoTheFreeEnd() {
        val row = listOf(mod("a", 600), end(900))
        val p = insertAt(row, 1000, mod("n", 600), false)
        assertEquals(listOf("a" to 600, "n" to 600, END_ID to 300), ws(p.row))
    }

    @Test fun betweenTwoModulesTheOthersShift() {
        val row = listOf(mod("a", 600), mod("b", 600), mod("c", 600), gap("g", 800), end(0))
        val p = insertAt(row, 590, mod("n", 450), false)
        assertTrue(p.ok)
        assertEquals(listOf("a", "n", "b", "c", "g", END_ID), p.row.map { it.id })
        assertEquals(350, p.row.first { it.id == "g" }.w)
        assertEquals(listOf("g" to 450), p.took)
        // no room: red with the reason
        val full = listOf(mod("a", 600), mod("b", 600), end(0))
        val q = insertAt(full, 600, Slot("dw", 600, SK.FIXED, listOf(450, 600)), true)
        assertFalse(q.ok); assertEquals("noRoom", q.why); assertEquals(0, q.free)
        // the free end gives room too, nearest first
        val r = insertAt(listOf(mod("a", 600), fill("f", 50), mod("b", 600), end(600)), 600, mod("n", 600), false)
        assertEquals(listOf("f" to 50, END_ID to 550), r.took)
    }

    @Test fun neverPastTheCornerUnit() {
        val row = listOf(mod("a", 600), Slot("k", 600, SK.CORNER), end(500))
        val p = insertAt(row, 1250, mod("n", 300), false)
        // the drop past the corner lands in the free end (it is a gap there)
        assertTrue(p.ok)
        val i = insertAt(listOf(mod("a", 600), Slot("k", 600, SK.CORNER), end(0)), 1190, mod("n", 300), false)
        assertFalse(i.ok)
    }

    /* ---------------- copy ---------------- */

    @Test fun copyGoesRight() {
        val row = listOf(mod("a", 600), mod("b", 450), fill("f", 50), gap("g", 800), end(0))
        val p = copyRight(row, 1, "b2")
        assertTrue(p.ok)
        assertEquals(listOf("a", "b", "b2", "g", END_ID), p.row.map { it.id })
        // the nearest filler first, then the gap
        assertEquals(listOf("f" to 50, "g" to 400), p.took)
        assertEquals(400, p.row.first { it.id == "g" }.w)
        // no room: a warning
        val q = copyRight(listOf(mod("a", 600), mod("b", 600), end(100)), 0, "x")
        assertFalse(q.ok); assertEquals(100, q.free)
        // a wardrobe's copy divides it equally again
        assertEquals(listOf(480, 480, 480, 480, 480), secCopy(listOf(600, 600, 600, 600), 1))
        assertNull(secCopy(List(6) { 400 }, 0))
        assertEquals(listOf(1200, 600, 600), secDelete(listOf(600, 600, 600, 600), 1))
        assertEquals(listOf(1200, 600), secDelete(listOf(600, 600, 600), 0))
        assertNull(secDelete(listOf(2400), 0))
    }

    /* ---------------- move ---------------- */

    @Test fun moveOrderByTheMiddle() {
        val row = listOf(mod("a", 600), mod("b", 600), mod("c", 600), mod("d", 600), end(0))
        // b dragged right until its middle is near 1500: after c
        val (o, at) = moveOrder(row, 1, 1550.0)
        assertEquals(listOf("a", "c", "b", "d", END_ID), o.map { it.id }); assertEquals(2, at)
        // to the very start
        assertEquals(listOf("d", "a", "b", "c", END_ID), moveOrder(row, 3, 100.0).first.map { it.id })
        // a corner unit at the end stays the end
        val k = listOf(mod("a", 600), mod("b", 600), Slot("k", 600, SK.CORNER), end(0))
        assertEquals(listOf("b", "a", "k", END_ID), moveOrder(k, 0, 5000.0).first.map { it.id })
        // one step left or right; never over the corner
        assertEquals(listOf("b", "a", "k", END_ID), moveBy(k, 0, 1)?.map { it.id })
        assertNull(moveBy(k, 1, 1)); assertNull(moveBy(k, 0, -1))
    }

    @Test fun alignAWallUnitOverTheOneUnder() {
        val row = listOf(mod("w1", 600), mod("w2", 500), mod("w3", 700), end(0))
        // w2 (600..1100) over a 600 at 600..1200: w3 gives 100
        val a = alignTo(row, 1, 600, 600)
        assertNotNull(a); assertEquals(listOf(600, 600, 600), a!!.filter { it.kind != SK.END }.map { it.w })
        // its left neighbour too narrow
        assertNull(alignTo(listOf(mod("w1", 160), mod("w2", 500), end(0)), 1, 0, 660))
    }

    /* ---------------- the kitchen's rows ---------------- */

    private val wsK = Workshop()

    private fun kitchen(): Furniture {
        val ms = listOf(template("sink", wsK, "A", 600), template("dishwasher", wsK, "A", 600), template("drawers", wsK, "A", 600),
            template("fillerLow", wsK, "A", 50), template("wall", wsK, "A", 600), template("base", wsK, "A", 450))
        return Furniture("k", "kitchen", walls = listOf("A"), modules = ms)
    }

    @Test fun aKitchenRowAndBack() {
        val f = kitchen()
        val r = Run("A", 3000, 0, 0)
        val row = kRow(f, r, false)
        assertEquals(listOf(SK.MOD, SK.FIXED, SK.MOD, SK.FILLER, SK.MOD, SK.END), row.map { it.kind })
        assertEquals(700, row.last().w)
        // the sink narrower: the filler grows into a gap
        val rs = resize(row, 0, 450)
        val g = pack(applyRow(f, "A", false, rs.row, wsK), listOf(r))
        val low = rowMods(g, "A", false)
        assertEquals(listOf(450, 600, 600, 200, 450), low.map { it.w })
        assertEquals("gap", low[3].type); assertEquals("space", low[3].app)
        // the wall unit kept its place in the list
        assertEquals(1, rowMods(g, "A", true).size)
        // deleted: a gap of its id
        val d = applyRow(f, "A", false, deleteToGap(row, 2), wsK)
        assertEquals("gap", d.modules.first { it.id == row[2].id }.type)
    }

    @Test fun aUnitsTypeInPlace() {
        val m = template("base", wsK, "A", 450).copy(front = "ag_white", soft = false)
        val dr = retype(m, "drawer3", wsK)!!
        assertEquals(Fronts("drawer", 3), dr.fronts); assertEquals(m.id, dr.id); assertEquals(450, dr.w)
        assertEquals("ag_white", dr.front); assertFalse(dr.soft)
        assertEquals("drawer3", curType(dr))
        // a dishwasher only 450 or 600 wide; a lower type never on a wall unit
        assertEquals("gap", retype(m, "dw", wsK)!!.type)
        assertNull(retype(m.copy(w = 500), "dw", wsK))
        assertNull(retype(template("wall", wsK, "A", 600), "door1", wsK))
        val v = retype(template("wall", wsK, "A", 600), "wglass", wsK)!!
        assertTrue(glassDoors(v)); assertEquals("wglass", curType(v))
    }

    @Test fun hingeSidesPerDoor() {
        val one = template("base", wsK, "A", 450)
        assertFalse(kHingeRight(one, 0))
        val r = withHinge(one, 0, "R")
        assertTrue(kHingeRight(r, 0)); assertEquals(listOf("R"), r.hinges)
        // back to the usual: nothing written
        assertEquals(emptyList<String>(), withHinge(r, 0, "L").hinges)
        val pair = template("base", wsK, "A", 800)
        assertTrue(kHingeRight(pair, 1))
        assertFalse(kHingeRight(withHinge(pair, -1, "L"), 1))
    }

    @Test fun ownFrontsAreCutAndPriced() {
        val f = kitchen()
        val sink = f.modules[0]
        val g = f.copy(modules = f.modules.map { if (it.id == sink.id) it.copy(front = "ag_white") else it })
        val mats = partsWithMat(g, wsK).filter { it.first.mod == sink.id && it.first.role == "front" }.map { it.second }.toSet()
        assertEquals(setOf("ag_white"), mats)
        // the others keep the piece's board
        assertTrue(partsWithMat(g, wsK).filter { it.first.mod != sink.id && it.first.role == "front" }.all { it.second == g.mats.front })
        assertEquals(setOf("ag_white"), ownFronts(g))
        assertTrue(ownFronts(clearOwnFronts(g)).isEmpty())
        // a section's own board
        val w = Module("w", "wardrobe", 1200, 2000, 600, legs = false, sections = listOf(Section(600, Fronts("door", 1), front = "wd_walnut"), Section(600, Fronts("door", 1))))
        val wf = Furniture("x", "wardrobe", modules = listOf(w))
        val pm = partsWithMat(wf, wsK).filter { it.first.key == "fp.door" }
        assertEquals(setOf("wd_walnut", wf.mats.front), pm.map { it.second }.toSet())
        assertEquals("wd_walnut", secFrontOf(wf, w, 0)); assertEquals(wf.mats.front, secFrontOf(wf, w, 1))
    }

    @Test fun aSectionsInsideFromItsCounts() {
        val s = Section(600, Fronts("door", 1))
        val ih = 2000
        val x = withFill(s, SecFill(true, 2, 2), ih, 16)
        val f = secFill(x)
        assertTrue(f.rail); assertEquals(2, f.shelves); assertEquals(2, f.drawers)
        // the drawers stacked from the floor, the rail over them
        val dr = x.inserts.filter { it.kind == "drawer" }.map { it.pos }.sorted()
        assertEquals(0, dr[0]); assertTrue(dr[1] >= 200)
        assertTrue(x.inserts.first { it.kind == "rail" }.pos > dr[1] + 200)
        assertEquals(SecFill(false, 0, 0), secFill(withFill(x, SecFill(false, 0, 0), ih, 16)))
        assertEquals("mirror", secType(withSecType(s, "mirror")))
        assertEquals("open", secType(withSecType(s, "open")))
        assertEquals(Fronts("door", 2), withSecType(Section(800, Fronts("open", 0)), "door").fronts)
    }

    @Test fun sectionsCountedAndReordered() {
        val m = Module("w", "wardrobe", 2400, 2000, 600, sections = listOf(Section(1200, Fronts("door", 2)), Section(1200, Fronts("door", 2), face = "mirror")))
        val n = withSecCount(m, 4, wsK)
        assertEquals(listOf(600, 600, 600, 600), n.sections.map { it.w })
        assertEquals("mirror", n.sections[1].face)
        val o = withSecOrder(m, listOf(1, 0))
        assertEquals("mirror", o.sections[0].face)
        val w = withSecWidths(m, listOf(1000, 1400))
        assertEquals(listOf(1000, 1400), splitSections(2400, w.sections).map { it.w })
    }
}
