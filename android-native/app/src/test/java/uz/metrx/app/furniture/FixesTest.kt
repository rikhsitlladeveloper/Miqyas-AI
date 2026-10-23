package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The furniture fixes of 23 Oct 2026: a stenka's last floor piece and shelves, corner arms, long parts priced, items fitted, a loft's under-part. */
class FixesTest {
    private val ws = Workshop()
    private fun piece(id: String, v: Map<String, Int> = emptyMap()) = pieceOf(fModel(id)!!, v, ws, id)

    @Test fun aStenkaWithOnlyItsShelfLeftStillHasSizesAndKeepsItsLastFloorPiece() {
        val f = piece("stenka")
        val bs = boxes(f)
        val shelf = bs.single { hung(it) }
        // an older order with every floor piece gone: its sizes do not throw
        val bare = f.copy(modules = f.modules.filter { it.id == shelf.id })
        val v = valsOf(bare, ws)
        assertTrue(v.getValue("h") > 0 && v.getValue("d") > 0)
        // the last floor piece cannot be taken away, a shelf always can
        val one = packPiece(f.copy(modules = f.modules.filter { hung(it) || it.id == bs.first { b -> !hung(b) }.id }), ws = ws)
        assertFalse(canDropBox(one, boxes(one).single { !hung(it) }))
        assertTrue(canDropBox(one, boxes(one).single { hung(it) }))
        assertTrue(canDropBox(f, bs.first { !hung(it) }))
    }

    @Test fun aStenkaShelfHangsOverALowPieceNeverATallOne() {
        val f = piece("stenka")
        val bs = boxes(f)
        val shelf = bs.single { hung(it) }; val tv = bs.single { !hung(it) && it.h < STENKA_TALL }
        // moved left past the first tall cabinet in the list: still over the TV unit
        val moved = packPiece(f.copy(modules = listOf(shelf) + f.modules.filter { it.id != shelf.id }), ws = ws)
        val s2 = moved.modules.single { it.id == shelf.id }; val tv2 = moved.modules.single { it.id == tv.id }
        assertEquals(tv2.x + (tv2.w - s2.w) / 2, s2.x)
        // a new shelf goes in next to the low piece, whichever box is picked
        assertEquals(bs.indexOf(tv) + 1, stenkaShelfAt(f.modules, 0))
        assertEquals(bs.indexOf(tv) + 1, stenkaShelfAt(f.modules, bs.lastIndex))
    }

    @Test fun cornerPiecesKeepTheTypedArmLengths() {
        assertEquals(1200, valsOf(piece("cornerW", mapOf("w" to 1200, "d" to 600)), ws)["w"])
        assertEquals(1000, valsOf(piece("cornerW", mapOf("w" to 1000, "d" to 700)), ws)["w"])
        assertEquals(1800, valsOf(piece("cornerW"), ws)["w"])
        val desk = piece("cornerDesk", mapOf("w2" to 1100, "d" to 800))
        assertEquals(1100, valsOf(desk, ws)["w2"])
        // the corner wardrobe's arm starts in the corner when its unit takes the whole length
        assertEquals(W_GAP_SIDE, boxes(piece("cornerW", mapOf("w" to 1000, "d" to 700))).filter { it.wall == "A" }.minOf { it.x })
    }

    @Test fun aPartLongerThanTheSheetIsPricedAndFlagged() {
        val ok = piece("h2")
        val tall = resized(ok, mapOf("h" to 3000), ws)
        val m = wardOfF(tall)!!
        val cost = costOf(listOf(tall), ws, MAT_PRESETS, HW_PRESETS)
        val lay = cost.layouts.first { it.unplaced.isNotEmpty() }
        val board = cost.lines.single { it.group == "mat" && it.key == lay.mat }
        assertEquals((lay.sheets.size + lay.unplaced.size).toDouble(), board.qty, 0.0)
        assertTrue(wardrobeChecks(m, null, null, ws, emptyList(), emptyList()).any { it.key == "wc.sheet" && it.level == "err" })
        assertTrue(wardrobeChecks(wardOfF(ok)!!, null, null, ws, emptyList(), emptyList()).none { it.key == "wc.sheet" })
    }

    @Test fun glassDoorsHaveNoHandles() {
        val up = piece("vitrina").modules[1]
        assertEquals("glass", up.sections.single().face)
        assertEquals(null, hardwareOf(up, ws)["handle"])
        assertTrue((hardwareOf(piece("vitrina").modules[0], ws)["handle"] ?: 0) > 0)
    }

    @Test fun aNarrowMirrorPanelKeepsItsHooksOnIt() {
        val f = piece("mirrorP", mapOf("w" to 500))
        val m = wardOfF(f)!!
        val hooks = itemBoards(m, ws).filter { it.role == "metal" && it.a1 - it.a0 == 16 && it.n1 - it.n0 == 60 }
        assertTrue(hooks.isNotEmpty())
        hooks.forEach { assertTrue("${it.a0}..${it.a1} on a ${m.w} panel", it.a0 >= 0 && it.a1 <= m.w) }
    }

    @Test fun aLoftBedsUnderPartGrowsBackWithTheFrame() {
        val f = piece("loft")
        val bed = f.modules.first { it.type == "loft" }
        val desk0 = f.modules.first { it.type == "wardrobe" }
        val small = packPiece(f.copy(modules = f.modules.map { if (it.id == bed.id) itemSized(itemSet(it, "ml", 1600, ws), ws) else it }), changed = bed.id, ws = ws)
        val big = packPiece(small.copy(modules = small.modules.map { if (it.id == bed.id) itemSized(itemSet(it, "ml", 2000, ws), ws) else it }), changed = bed.id, ws = ws)
        assertEquals(desk0.w, big.modules.first { it.type == "wardrobe" }.w)
    }

    @Test fun fitToTheWallNarrowsATableButNotABed() {
        val t = piece("dining", mapOf("w" to 1600))
        val fitted = fitTo(placed(t, listOf("A"), "r", "w", len = { 1200 }), listOf("A"), { 1200 }, 2700, ws)
        assertTrue(fitIssues(fitted, listOf("A"), { 1200 }, 2700, ws).isEmpty())
        val bed = piece("bed", mapOf("mw" to 1600))
        val b2 = fitTo(placed(bed, listOf("A"), "r", "w", len = { 1200 }), listOf("A"), { 1200 }, 2700, ws)
        assertEquals(fitIssues(bed, listOf("A"), { 1200 }, 2700, ws), fitIssues(b2, listOf("A"), { 1200 }, 2700, ws))
        // deeper than the room in front of its wall: said, and fitting does not take it away
        assertTrue(fitIssues(bed, listOf("A"), { 4000 }, 2700, ws, deep = { 1500 }).any { it.key == "fz.deep" })
        assertEquals(3000, depthFrom(uz.metrx.app.data.Pt(0.0, 0.0), uz.metrx.app.data.Pt(4000.0, 0.0),
            listOf(uz.metrx.app.data.Pt(0.0, 0.0), uz.metrx.app.data.Pt(4000.0, 0.0), uz.metrx.app.data.Pt(4000.0, 3000.0), uz.metrx.app.data.Pt(0.0, 3000.0))))
    }

    @Test fun theQuoteDescribesPiecesOfSeveralBoxesByTheirOwnSizes() {
        assertEquals("3000 × 2200 × 400 mm", sizeLine(piece("stenka"), ws, "mm"))
        assertEquals("1600 × 2000 · h 450 mm", sizeLine(piece("bed", mapOf("mw" to 1600)), ws, "mm"))
        assertTrue(sizeLine(piece("cornerW"), ws, "mm").startsWith("1800 + 1600"))
    }
}
