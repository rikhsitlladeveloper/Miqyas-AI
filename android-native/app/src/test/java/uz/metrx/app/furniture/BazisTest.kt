package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The ideas taken from Bazis Mebelshchik (23 Oct 2026): remnants, labels, the Check list, corner pieces, Change for all. */
class BazisTest {
    private val ws = Workshop()
    private fun piece(id: String, v: Map<String, Int> = emptyMap()) = pieceOf(fModel(id)!!, v, ws, id)
    private fun row(key: String, L: Int, W: Int, grain: Boolean = false, mat: String = "ldsp16w") = CutRow(FPart(key, "", "carcass", L, W, 1, grain = grain), mat, L, W)
    private var n = 0
    private val ids = { "r${++n}" }

    /* ---------------- remnants ---------------- */

    @Test fun aFittingRemnantIsUsedBeforeANewSheet() {
        val rows = listOf(row("fp.shelf", 700, 400))
        val l = layout(rows, "ldsp16w", 2800, 2070, 4, 10, listOf(Remnant("a", "ldsp16w", 800, 500), Remnant("b", "ldsp18a", 800, 500)))
        assertEquals(0, l.sheets.size); assertEquals(1, l.rems.size); assertEquals("a", l.rems[0].rem!!.id)
        // what is left of the remnant: the end of the strip and the width under it
        assertTrue(l.rems[0].rest.any { it == 96 to 400 } && l.rems[0].rest.any { it == 800 to 96 })
        // the smallest that fits goes first
        val two = layout(rows, "ldsp16w", 2800, 2070, 4, 10, listOf(Remnant("big", "ldsp16w", 2000, 1000), Remnant("small", "ldsp16w", 720, 420)))
        assertEquals("small", two.rems.single().rem!!.id)
    }

    @Test fun aRemnantKeepsTheGrain() {
        // the remnant is 450 along the grain and 800 across: a part with grain 700 long cannot lie across it
        val rem = listOf(Remnant("g", "ldsp16k", 450, 800, grain = true))
        val grained = layout(listOf(row("fp.door", 700, 400, grain = true, mat = "ldsp16k")), "ldsp16k", 2800, 2070, 4, 10, rem)
        assertEquals(0, grained.rems.size); assertEquals(1, grained.sheets.size)
        val plain = layout(listOf(row("fp.shelf", 700, 400, mat = "ldsp16k")), "ldsp16k", 2800, 2070, 4, 10, rem)
        assertEquals(1, plain.rems.size); assertEquals(0, plain.sheets.size)
        assertTrue(plain.rems[0].placed.single().turned)
    }

    @Test fun cuttingAnOrderTakesItsRemnantsAndKeepsItsOffcuts() {
        val store = listOf(Remnant("old", "ldsp16w", 800, 500, src = "o0"), Remnant("other", "ldsp18a", 900, 900, src = "o0"))
        val f = piece("dresser")
        val lays = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, rems = remnantsFor(store, "o1", false)).layouts
        assertTrue(lays.any { l -> l.rems.any { it.rem!!.id == "old" } })
        val after = cutDone(store, lays, MAT_PRESETS, "o1", 300, 5, ids)
        assertEquals("o1", after.single { it.id == "old" }.used)
        val kept = after.filter { it.src == "o1" }
        assertTrue(kept.isNotEmpty()); assertTrue(kept.all { it.L >= 300 && it.W >= 300 && it.used.isEmpty() })
        // the kept board of a grained material says so
        assertTrue(kept.filter { it.mat == "ldsp16k" }.all { it.grain })
        // another order: not the taken one, the new offcuts yes; the cut order: exactly what it took
        val next = remnantsFor(after, "o2", false)
        assertFalse(next.any { it.id == "old" }); assertTrue(next.containsAll(kept))
        assertEquals(listOf("old"), remnantsFor(after, "o1", true).map { it.id })
        // a deleted order's remnants stay taken: that board was cut
        assertFalse(remnantsFor(after, "o2", false).any { it.id == "old" })
        // undone: as before
        assertEquals(store, cutUndone(after, "o1"))
        // done twice: nothing kept twice
        assertEquals(after.size, cutDone(after, lays, MAT_PRESETS, "o1", 300, 6, ids).size)
    }

    @Test fun theCostCountsOnlyNewSheets() {
        val f = piece("dresser")
        val plain = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS)
        val lay = plain.layouts.first { it.mat == f.mats.carcass }
        val sheet = MAT_PRESETS.first { it.id == f.mats.carcass }
        assertEquals(lay.sheets.size.toDouble(), plain.lines.first { it.group == "mat" && it.key == f.mats.carcass }.qty, 0.0)
        // as many whole remnants as the carcass took sheets: no carcass sheet is bought
        val rems = List(lay.sheets.size) { Remnant("w$it", f.mats.carcass, sheet.l - 2 * ws.trim, sheet.w - 2 * ws.trim) }
        val withRems = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, rems = rems)
        // no sheet bought: no line at all (not a 0-sheet line saying its price is missing)
        assertTrue(withRems.lines.none { it.group == "mat" && it.key == f.mats.carcass })
        assertTrue(withRems.total < plain.total)
        // cutting them is still work
        assertEquals(plain.lines.first { it.key == "fc.cut" }.qty, withRems.lines.first { it.key == "fc.cut" }.qty, 0.0)
        // the customer's price stays; the profit grows
        val fp = FPrice()
        assertEquals(priceOf(listOf(f), fp, ws, MAT_PRESETS, HW_PRESETS).price, priceOf(listOf(f), fp, ws, MAT_PRESETS, HW_PRESETS, rems).price)
    }

    /* ---------------- labels ---------------- */

    @Test fun labelsAreOneAPartTwentyFourToAPage() {
        assertEquals(24, LABELS_PER_PAGE)
        assertEquals(1, labelPages(1)); assertEquals(1, labelPages(24)); assertEquals(2, labelPages(25)); assertEquals(0, labelPages(0))
        assertEquals(Triple(0, 0, 0), labelSlot(0)); assertEquals(Triple(0, 2, 0), labelSlot(2)); assertEquals(Triple(0, 0, 1), labelSlot(3))
        assertEquals(Triple(0, 2, 7), labelSlot(23)); assertEquals(Triple(1, 0, 0), labelSlot(24))
        val fs = listOf(piece("dresser"), piece("h3"))
        val ls = labelsOf(fs, ws)
        assertEquals(cutList(fs, ws).sumOf { it.p.qty }, ls.size)
        assertEquals((1..ls.size).toList(), ls.map { it.n })
        assertTrue(ls.any { it.bands.any })
        assertEquals("MX-abc123-007", labelId("abc123-xyz", 7))
    }

    /* ---------------- the Check list ---------------- */

    @Test fun theCheckListCollectsEveryPiecesProblems() {
        val wide = Module("m1", "wardrobe", 1200, 2000, 600, wall = "A", legs = false,
            sections = listOf(Section(1200, Fronts("open", 0), listOf(Insert("shelf", 400)))))
        val shallow = Module("m2", "wardrobe", 600, 1000, 300, wall = "A", legs = false,
            sections = listOf(Section(600, Fronts("open", 0), listOf(Insert("drawer", 100, h = 200)))))
        val tall = Module("m3", "wardrobe", 600, 2900, 600, wall = "A", legs = false, sections = listOf(Section(600, Fronts("door", 1))))
        val a = Furniture("a", "wardrobe", "A", null, listOf("A"), listOf(wide))
        val b = Furniture("b", "wardrobe", "B", null, listOf("A"), listOf(shallow, tall))
        val ok = piece("dresser").copy(id = "c")
        val found = orderChecks(listOf(a, b, ok), ws, MAT_PRESETS) { f -> if (f.id == "a") listOf(OrderIssue("a", "err", "fz.doorsHit", mapOf("n" to "B"))) else emptyList() }
        assertTrue(found.any { it.fid == "a" && it.key == "bz.ck.shelf" && it.vars["v"] == 1166 && it.vars["max"] == 1000 })
        assertTrue(found.any { it.fid == "b" && it.key == "bz.ck.drawer" && it.mid == "m2" })
        assertTrue(found.any { it.fid == "b" && it.key == "bz.ck.sheet" && it.vars["l"] == 2900 })
        assertTrue(found.any { it.fid == "a" && it.key == "fz.doorsHit" })
        assertTrue(found.none { it.fid == "c" })
        // errors first
        assertEquals(found.sortedBy { if (it.level == "err") 0 else 1 }, found)
        // 18 mm board carries 1100 mm; a usual corner wardrobe has nothing to say
        assertEquals(1100, shelfSpanMax(18))
        assertTrue(orderChecks(listOf(a), ws.copy(t = 18), MAT_PRESETS).single { it.key == "bz.ck.shelf" }.vars["max"] == 1100)
        listOf(0, 1, 2, 3).forEach { sh -> assertTrue("$sh", orderChecks(listOf(piece("cornerW", mapOf("sh" to sh))), ws, MAT_PRESETS).isEmpty()) }
    }

    /* ---------------- corner pieces: the shape and whichever sides were measured ---------------- */

    @Test fun aCornerPieceIsBuiltFromWhicheverSidesWereMeasured() {
        val m = fModel("cornerW")!!
        assertEquals(listOf("sh", "ms", "ai", "bi", "h", "d"), stepsOf(m, mapOf("ms" to 1)).map { it.key })
        assertEquals(listOf("sh", "ms", "la", "lb", "h", "d"), stepsOf(m, mapOf("ms" to 2)).map { it.key })
        // the fronts: arm A along its wall is its front plus the other arm's depth (less the gap at the corner)
        val fr = derive(m, mapOf("ms" to 1, "ai" to 1500, "bi" to 1200, "d" to 600))
        assertEquals(1500 + 600 - W_GAP_SIDE, fr["w"]); assertEquals(1800, fr["w2"])
        val v = valsOf(pieceOf(m, mapOf("ms" to 1, "ai" to 1500, "bi" to 1200, "d" to 600), ws, "x"), ws)
        assertEquals(fr["w"], v["w"]); assertEquals(fr["w2"], v["w2"])
        // the walls: a gap at each end of the first, at the end of the second
        val wl = derive(m, mapOf("ms" to 2, "la" to 2400, "lb" to 2000))
        assertEquals(2400 - 2 * W_GAP_SIDE, wl["w"]); assertEquals(2000 - W_GAP_SIDE, wl["w2"])
        // the usual sizes are the same piece whichever way it is measured
        assertEquals(derive(m, mapOf("ms" to 0))["w"] ?: stepsOf(m).first { it.key == "w" }.usual, derive(m, mapOf("ms" to 1))["w"])
        // what was worked out is shown: typed along the walls, the fronts and the walls come out
        val shown = derivedSides(m, mapOf("ms" to 0, "w" to 1800, "w2" to 1600, "d" to 600))
        assertEquals(listOf("bz.ai", "bz.bi", "bz.la", "bz.lb"), shown.map { it.first })
        assertEquals(listOf(1210, 1000, 1820, 1610), shown.map { it.second })
        // a front too short for the piece is marked, and the piece stays within its sizes
        assertTrue(derivedSides(m, mapOf("ms" to 1, "ai" to 300, "bi" to 300, "d" to 600)).any { it.third })
        // the L kitchen: the worktop's front edges
        val k = fModel("L")!!
        assertEquals(listOf("sh", "ms", "f0", "f1", "h"), stepsOf(k, mapOf("ms" to 1)).map { it.key })
        val kd = derive(k, mapOf("ms" to 1, "f0" to 2400, "f1" to 1400))
        assertEquals(3000, kd["s0"]); assertEquals(2000, kd["s1"])
        assertEquals(listOf(3000, 2000), pieceOf(k, mapOf("ms" to 1, "f0" to 2400, "f1" to 1400), ws, "k").free!!.sides)
    }

    @Test fun aCornerPiecesShapeIsBuiltAsPictured() {
        val m = fModel("cornerW")!!
        assertEquals(4, shapesOf(m).size); assertEquals(2, shapesOf(fModel("cornerDesk")!!).size); assertEquals(2, shapesOf(fModel("L")!!).size)
        assertTrue(shapesOf(fModel("I")!!).isEmpty())
        val right = piece("cornerW")
        assertEquals(listOf("A", "B"), right.walls); assertEquals("", right.hand)
        // corner on the left, open shelves: the same arms on the made-up room's left and back walls
        val openL = piece("cornerW", mapOf("sh" to 3))
        assertEquals(listOf("D", "A"), openL.walls); assertEquals("L", openL.hand)
        val corner = boxes(openL).single { b -> b.sections.any { it.blind > 0 } }
        assertEquals("open", corner.sections.single().fronts.kind)
        assertTrue(corner.sections.single().inserts.count { it.kind == "shelf" } >= 3)
        assertEquals(3, valsOf(openL, ws)["sh"])
        // its made-up room: the left wall carries the first arm, the back wall the second
        val r = freeRoom(openL)
        assertEquals(valsOf(openL, ws)["w"]!! + 2 * W_GAP_SIDE, r.dim("B").v)
        // no hinges on the open corner
        assertTrue((hardware(listOf(openL), ws)["hingeSoft"] ?: 0) < (hardware(listOf(right), ws)["hingeSoft"] ?: 0))
        // sizes changed later keep the shape
        val bigger = resized(openL, mapOf("w" to 2000), ws)
        assertEquals("L", bigger.hand); assertEquals(listOf("D", "A"), bigger.walls)
        // the L kitchen with its corner on the left goes D then A; taken out of a room it stays so
        val kl = piece("L", mapOf("sh" to 1, "s0" to 3200, "s1" to 2100))
        assertEquals(listOf("D", "A"), kl.walls); assertEquals("L", kl.hand)
        // its runs go from the side wall (2100) to the main, back wall (3200); the sizes come back as typed
        assertEquals(listOf(2100, 3200), kl.free!!.sides)
        assertEquals(3200, freeRoom(kl).dim("A").v); assertEquals(2100, freeRoom(kl).dim("B").v)
        assertEquals(1, valsOf(kl, ws)["sh"]); assertEquals(3200, valsOf(kl, ws)["s0"]); assertEquals(2100, valsOf(kl, ws)["s1"])
        assertEquals(listOf(2100, 3400), resized(kl, mapOf("s0" to 3400), ws).free!!.sides)
        val desk = piece("cornerDesk", mapOf("sh" to 1))
        assertEquals(listOf("D", "A"), desk.walls)
        assertEquals(listOf("D", "A"), takenOut(placed(desk, listOf("B", "C"), "room", "w", ws = ws), { 3000 }, 2700).walls)
    }

    /* ---------------- Change for all ---------------- */

    @Test fun changeForAllChangesEveryPieceAndTheOldOnesComeBack() {
        val fs = listOf(piece("dresser"), piece("h3"), piece("L"))
        val fronts = swapAll(fs, front = "mdf18")
        assertTrue(fronts.all { it.mats.front == "mdf18" }); assertEquals("mdf18", commonFront(fronts))
        assertEquals(fs.map { it.mats.carcass }, fronts.map { it.mats.carcass })
        val none = swapAll(fronts, handle = NO_HANDLES)
        assertEquals(NO_HANDLES, commonHandle(none))
        assertEquals(0, hardware(none, ws)["handle"] ?: 0)
        val knobs = swapAll(none, handle = "handleKnob")
        assertEquals("handleKnob", commonHandle(knobs))
        // the knobs are priced as knobs, not as the usual handle
        val c = costOf(knobs, ws, MAT_PRESETS, HW_PRESETS)
        val nHandles = hardware(knobs, ws)["handle"] ?: 0
        assertTrue(nHandles > 0)
        assertEquals(nHandles.toDouble(), c.lines.single { it.group == "hw" && it.key == "handleKnob" }.qty, 0.0)
        assertTrue(c.lines.none { it.group == "hw" && it.key == "handle" })
        // Undo: the pieces kept from before are the pieces as they were
        assertNotEquals(fs, knobs)
        assertEquals(listOf("ldsp16k", "ldsp16k", "ldsp16k"), fs.map { it.mats.front })
        assertTrue(fs.all { f -> f.modules.filter { it.type != "gap" }.all { it.handles } })
        // the usual price is the skoba's, whatever handle presets came after it
        assertEquals("handle", usualHw(HW_PRESETS, "handle")!!.id)
        assertEquals(costOf(fs, ws, MAT_PRESETS, HW_PRESETS).total, costOf(swapAll(fs, handle = ""), ws, MAT_PRESETS, HW_PRESETS).total)
    }
}
