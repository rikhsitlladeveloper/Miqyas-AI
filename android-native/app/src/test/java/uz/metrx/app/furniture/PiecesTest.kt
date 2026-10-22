package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room

/** The gallery's later models (Pieces.kt, Cabinets.kt): their steps, pieces of several boxes, where the boxes go, how they are placed. */
class PiecesTest {
    private val ws = Workshop()
    private val newer = listOf("dining", "bar", "pantry", "cornerW", "bed", "vanity", "shelfW", "tvBed", "stenka", "vitrina", "coffee", "shelvesW",
        "shoe", "hallW", "mirrorP", "bunk", "loft", "kidsW", "toys", "cornerDesk", "bookcase", "officeC", "sinkV", "mirrorC", "penal", "washer")
    private fun piece(id: String, v: Map<String, Int> = emptyMap()) = pieceOf(fModel(id)!!, v, ws, id)

    @Test fun everyNewerModelIsInTheGalleryWithItsRoom() {
        val ids = GALLERY.flatMap { it.second }
        newer.forEach { assertTrue(it, it in ids) }
        assertEquals(listOf("bunk", "loft", "kidsW", "toys"), GALLERY.first { it.first == "kids" }.second)
        assertEquals(listOf("sinkV", "mirrorC", "penal", "washer"), GALLERY.first { it.first == "bath" }.second)
    }

    @Test fun everyNewerModelHasPartsHardwareAndAPriceAndGivesBackItsSizes() {
        newer.forEach { id ->
            val m = fModel(id)!!
            val f = piece(id)
            assertEquals(id, "wardrobe", f.kind); assertEquals(id, id, f.type); assertEquals("other", kindKey(f))
            assertTrue(id, boxes(f).isNotEmpty())
            assertTrue(id, cutList(listOf(f), ws).isNotEmpty())
            assertTrue(id, hardware(listOf(f), ws).isNotEmpty())
            assertTrue(id, costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS).missing == 0)
            // what was asked comes back as asked
            val v = valsOf(f, ws)
            stepsOf(m).forEach { s -> assertEquals("$id ${s.key}", s.usual, v[s.key]) }
            // the cabinets pass the wardrobe checks (as in a room just big enough)
            f.modules.filter { it.type == "wardrobe" }.forEach { b ->
                val c = wardrobeChecks(b, b.x + b.w + 20, 3000, ws, emptyList(), emptyList())
                assertTrue("$id: ${c.filter { it.level == "err" }}", c.none { it.level == "err" })
            }
        }
    }

    @Test fun choicesAreStepsOfTheirOwn() {
        val bed = stepsOf(fModel("bed")!!)
        assertEquals(listOf("bt", "mw", "ml", "h", "hb"), bed.map { it.key })
        assertTrue(bed[0].choice); assertEquals(3, bed[0].opts.size)
        assertEquals(listOf(900, 1200, 1400, 1600, 1800), bed[1].picks)
        assertNull(stepIssue(bed[0], 2)); assertEquals("fx.max" to 2, stepIssue(bed[0], 3))
        assertEquals(listOf("mw", "ml", "h", "lad", "und"), stepsOf(fModel("loft")!!).map { it.key })
        assertEquals(listOf(800, 900), stepsOf(fModel("bunk")!!)[0].picks)
        assertEquals(listOf("w", "d", "h", "lg", "tp", "rc"), stepsOf(fModel("dining")!!).map { it.key })
        assertEquals(listOf("w", "h", "d", "e"), stepsOf(fModel("mirrorC")!!).map { it.key })
        assertEquals(listOf("w", "h", "d", "mt"), stepsOf(fModel("sinkV")!!).map { it.key })
        assertEquals(listOf("w", "w2", "h", "d"), stepsOf(fModel("cornerW")!!).map { it.key })
    }

    @Test fun aBedIsBuiltRoundItsMattressAndItsKindIsChosen() {
        val f = piece("bed", mapOf("bt" to 1, "mw" to 1400, "ml" to 2000))
        val m = wardOfF(f)!!
        assertEquals("bed", m.type); assertEquals("drawers", m.opt!!.bed)
        assertEquals(1400 + 2 * ws.t + 10, m.w); assertEquals(2000 + 2 * ws.t + 10, m.d); assertEquals(450, m.h)
        // a 1400 mattress has drawers on both sides, two a side
        assertEquals(4, bedDrawers(m, ws).size)
        assertEquals(4, partsOf(m, ws).filter { it.key == "fp.dFace" }.sumOf { it.qty })
        assertEquals(4, hardwareOf(m, ws)["runner"])
        assertEquals(1, partsOf(m, ws).single { it.key == "fp.headboard" }.qty)
        partsOf(m, ws).single { it.key == "fp.headboard" }.let { assertEquals(m.w, it.L); assertEquals(1000, it.W) }
        // a narrow one only on its right side
        assertEquals(listOf(1, 1), bedDrawers(wardOfF(piece("bed", mapOf("bt" to 1, "mw" to 900)))!!, ws).map { it.side })
        // lift-up: a mechanism and a box bottom, no slatted base bought apart
        val lift = wardOfF(piece("bed", mapOf("bt" to 2)))!!
        assertEquals(1, hardwareOf(lift, ws)["bedLift"]); assertNull(hardwareOf(lift, ws)["bedBase"])
        assertTrue(partsOf(lift, ws).any { it.key == "fp.boxBottom" })
        // on legs: legs, a slatted base
        val legs = wardOfF(piece("bed"))!!
        assertTrue((hardwareOf(legs, ws)["leg"] ?: 0) >= 4); assertEquals(1, hardwareOf(legs, ws)["bedBase"])
        // new sizes keep the kind; the frame follows the mattress
        val g = resized(f, mapOf("mw" to 1800, "hb" to 1200), ws)
        assertEquals(1800 + 2 * ws.t + 10, wardOfF(g)!!.w); assertEquals("drawers", wardOfF(g)!!.opt!!.bed); assertEquals(1200, wardOfF(g)!!.opt!!.hb)
        assertEquals(1200, itemTop(wardOfF(g)!!, ws))
    }

    @Test fun bunkAndLoftBedsStandAlongTheWallWithTheirLadder() {
        val b = wardOfF(piece("bunk", mapOf("lad" to 0)))!!
        assertEquals(2000 + 2 * ws.t + 10, b.w); assertEquals(900 + 2 * ws.t + 10 + LADDER_D, b.d)
        assertEquals("L", b.opt!!.ladder)
        assertEquals(2, hardwareOf(b, ws)["bedBase"])
        assertTrue(partsOf(b, ws).count { it.key == "fp.rung" } > 0 && partsOf(b, ws).single { it.key == "fp.ladder" }.qty == 2)
        // a loft bed with a desk, a cabinet or nothing under it, always under its platform and inside its frame
        val desk = piece("loft")
        assertEquals(listOf("loft", "wardrobe"), desk.modules.map { it.type })
        val bed = desk.modules[0]
        val ward = withUnder(desk, "ward", ws)
        val u = ward.modules[1]
        assertTrue(topOf(u, ws) <= upperDeck(bed) - 150)
        assertTrue(u.x >= bed.x && u.x + u.w <= bed.x + bed.w)
        assertTrue(u.sections.all { it.fronts.kind == "door" })
        assertEquals(1, withUnder(desk, "open", ws).modules.size)
        assertEquals("open", wardOfF(withUnder(desk, "open", ws))!!.opt!!.under)
    }

    @Test fun tablesHaveTheirLegsAndTop() {
        val board = wardOfF(piece("dining"))!!
        assertEquals(2, partsOf(board, ws).single { it.key == "fp.tLeg" }.qty)
        assertEquals(2, partsOf(board, ws).single { it.key == "fp.top" }.qty)                 // a dining top of two glued layers
        val metal = wardOfF(piece("dining", mapOf("lg" to 1)))!!
        assertEquals(4, hardwareOf(metal, ws)["tableLeg"]); assertTrue(partsOf(metal, ws).none { it.key == "fp.tLeg" })
        assertEquals(1, hardwareOf(wardOfF(piece("coffee", mapOf("lg" to 2)))!!, ws)["tableFrame"])
        val round = wardOfF(piece("coffee", mapOf("rc" to 1)))!!
        assertTrue(partsOf(round, ws).any { it.key == "fp.topR" })
        assertEquals(1, partsOf(round, ws).single { it.key == "fp.topR" }.qty)               // a coffee table's top is one board
        // a worktop top is bought by the metre, not cut
        val wt = piece("dining", mapOf("tp" to 1))
        assertTrue(partsOf(wardOfF(wt)!!, ws).none { it.key == "fp.top" })
        assertEquals(1.4, costOf(listOf(wt), ws, MAT_PRESETS, HW_PRESETS).lines.single { it.key == "wt38" }.qty, 1e-9)
        assertTrue(canStandFree(wt))
    }

    @Test fun theBarCounterAndTheMirrorPanel() {
        val bar = wardOfF(piece("bar"))!!
        assertEquals(1420, hardwareOf(bar, ws)["barRail"])
        assertTrue(partsOf(bar, ws).any { it.key == "fp.barFront" })
        val panel = wardOfF(piece("mirrorP"))!!
        assertEquals("hooks", panel.type); assertEquals(300, panel.elev); assertTrue(hung(panel))
        assertEquals(4, hardwareOf(panel, ws)["hook"]); assertEquals(450 * 1000, hardwareOf(panel, ws)["mirror"])
        assertEquals(300 + 1600 + ws.t, topOf(panel, ws))
    }

    @Test fun aStenkaIsItsPiecesSideBySideWithAShelfOverTheTvUnit() {
        val f = piece("stenka")
        val bs = boxes(f)
        assertEquals(4, bs.size)
        val floor = bs.filter { !hung(it) }
        floor.zipWithNext().forEach { (a, b) -> assertEquals(a.x + a.w, b.x) }
        assertEquals(3000, runLen(f))
        val tv = floor[1]; val shelf = bs.single { hung(it) }
        assertEquals(tv.x + (tv.w - shelf.w) / 2, shelf.x)
        // another tall cabinet after the TV unit: the rest move along, the shelf stays over the TV unit
        val g = packPiece(f.copy(modules = f.modules.toMutableList().apply { add(2, stenkaPart(f, "tall", ws)) }), ws = ws)
        assertEquals(3600, runLen(g))
        boxes(g).filter { !hung(it) }.zipWithNext().forEach { (a, b) -> assertEquals(a.x + a.w, b.x) }
        assertEquals("pc.shelf", boxRole(g, boxes(g).single { hung(it) }))
        assertEquals("pc.tall", boxRole(g, boxes(g).first()))
    }

    @Test fun aCornerWardrobeTakesTwoWallsAndClosesItsCorner() {
        val f = piece("cornerW")
        assertEquals(listOf("A", "B"), f.walls)
        val a = f.modules.filter { it.wall == "A" }; val b = f.modules.filter { it.wall == "B" }
        assertEquals(2, a.size); assertEquals(1, b.size)
        val corner = a.last()
        assertEquals(600, corner.sections.single().blind)
        assertEquals("pc.corner", boxRole(f, corner)); assertEquals("pc.armB", boxRole(f, b[0]))
        // its door covers the open part only
        assertEquals(1, partsOf(corner, ws).single { it.key == "fp.door" }.qty)
        assertEquals((400 * 10 - 2 * ws.edge10) / 10, partsOf(corner, ws).single { it.key == "fp.door" }.W)
        // the second arm starts past the first's depth
        assertEquals(corner.d, b[0].x)
        // in a room: it goes into the corner of the walls it is put on, its first arm ending there
        val room = Room("r", "w", "Xona", dims = mapOf("A" to Dim(3600), "B" to Dim(3000), "H" to Dim(2700)))
        assertEquals(listOf("C", "D"), placeWalls(f, listOf("A", "B", "C", "D"), "C"))
        val g = placed(f, listOf("A", "B"), "r", "w", len = { mapOf("A" to 3600, "B" to 3000)[it] })
        assertEquals(3600 - W_GAP_SIDE, g.modules.filter { it.wall == "A" }.maxOf { it.x + it.w })
        assertTrue(fitIssues(g, listOf("A", "B"), { mapOf("A" to 3600, "B" to 3000)[it] }, 2700, ws).isEmpty())
        assertEquals("fz.wide", fitIssues(g, listOf("A", "B"), { mapOf("A" to 1500, "B" to 3000)[it] }, 2700, ws).single().key)
        val walls = planWalls(room, true)
        assertEquals(3, footsOf(g, walls, ws).size)
        assertTrue(placeWarnings(g, emptyList(), room, walls, ws).isEmpty())
        // taken out again: the corner layout stays
        val t = takenOut(g, { mapOf("A" to 3600, "B" to 3000)[it] }, 2700)
        assertEquals(W_GAP_SIDE, t.modules.filter { it.wall == "A" }.minOf { it.x }); assertEquals(corner.d, t.modules.single { it.wall == "B" }.x)
    }

    @Test fun aCornerDeskGoesRoundTheCornerWithItsKneeSpace() {
        val f = piece("cornerDesk")
        val (a, b) = f.modules
        assertTrue(hasKnee(a) && hasKnee(b))
        assertFalse(b.sideL)                                       // its knee space runs on under the first arm's top
        assertTrue(b.sections.first().knee)
        assertEquals(1200, valsOf(f, ws)["w2"])
    }

    @Test fun aVitrinaAndAWasherColumnAreOneBoxOnAnother() {
        val v = piece("vitrina")
        val (lo, up) = v.modules
        assertEquals(topOf(lo, ws), up.elev); assertEquals(lo.x, up.x); assertEquals(lo.w, up.w)
        assertEquals("glass", up.sections.single().face); assertTrue(up.led)
        assertTrue(up.sections.single().inserts.all { it.kind == "glass" })
        val hw = hardwareOf(up, ws)
        assertTrue((hw["glassDoor"] ?: 0) > 0 && (hw["glassShelf"] ?: 0) > 0 && hw["led"] == up.w - 2 * ws.t && hw["ledPsu"] == 1)
        assertTrue(partsOf(up, ws).none { it.key == "fp.door" })   // its doors are bought, not cut
        // the box just changed leads: a wider upper one widens the lower
        val wider = stackPack(v.copy(modules = listOf(lo, up.copy(w = 1000))), up.id, ws)
        assertEquals(1000, wider.modules[0].w)
        val w = piece("washer")
        assertTrue(w.modules[0].sections.single().knee)              // the machine's niche: no bottom, no back
        assertTrue(partsOf(w.modules[0], ws).none { it.key == "fp.back" || it.key == "fp.plinth" })
        assertEquals(900, w.modules[1].elev)
    }

    @Test fun aDressingTableHasItsMirrorOverIt() {
        val f = piece("vanity", mapOf("rw" to 700, "rh" to 900))
        val cab = f.modules[0]; val mir = f.modules.single { it.type == "mirror" }
        assertTrue(hasKnee(cab))
        assertEquals(cab.x + (cab.w - 700) / 2, mir.x); assertEquals(900, mir.h)
        assertTrue(mir.elev >= topOf(cab, ws) + 50)
        assertEquals(700 * 900, hardwareOf(mir, ws)["mirror"])
        assertEquals(cab, wardOfF(f))
        val g = resized(f, mapOf("w" to 1200, "rw" to 800), ws)
        assertEquals(1200, g.modules[0].w); assertEquals(g.modules[0].x + (1200 - 800) / 2, g.modules.single { it.type == "mirror" }.x)
    }

    @Test fun bathroomPiecesAreOfMoistureResistantBoardAndHangOrStand() {
        assertTrue(MAT_PRESETS.any { it.id == MR_BOARD })
        BATH_TYPES.forEach { assertEquals(it, MR_BOARD, piece(it).mats.carcass) }
        val legs = wardOfF(piece("sinkV"))!!
        assertTrue(legs.legs); assertEquals(850, topOf(legs, ws))
        val wall = wardOfF(piece("sinkV", mapOf("mt" to 1)))!!
        assertTrue(hung(wall)); assertEquals(300, wall.elev); assertEquals(850, topOf(wall, ws))
        assertEquals(2, hardwareOf(wall, ws)["hanger"]); assertNull(hardwareOf(wall, ws)["leg"])
        assertTrue(partsOf(wall, ws).none { it.key == "fp.plinth" })
        val mc = wardOfF(piece("mirrorC"))!!
        assertEquals(1250, mc.elev); assertEquals("mirror", mc.sections.single().face); assertFalse(mc.handles)
        assertTrue((hardwareOf(mc, ws)["mirror"] ?: 0) > 0)
        assertEquals(mapOf("w" to 600, "h" to 700, "d" to 150, "e" to 1300), valsOf(resized(piece("mirrorC"), mapOf("e" to 1300), ws), ws))
    }

    @Test fun aBedStandsWithItsHeadboardOnAWallAndItsDrawersNeedRoom() {
        val room = Room("r", "w", "Xona", dims = mapOf("A" to Dim(4000), "B" to Dim(3500), "H" to Dim(2700)))
        val walls = planWalls(room, true)
        val f = placed(piece("bed", mapOf("bt" to 1)), listOf("A"), "r", "w", off = 1000)
        val ft = footsOf(f, walls, ws).single()
        assertEquals("A", ft.wall); assertEquals(1000.0, ft.a0, 1e-9); assertEquals(1000.0 + wardOfF(f)!!.w, ft.a1, 1e-9)
        assertTrue(canStandFree(f))
        // its drawers pull out from both long sides
        assertEquals(4, swingsOf(f, walls, ws).size)
        // a wardrobe right beside it is in the way of the drawers
        val w = placed(newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws), listOf("A"), "r", "w", off = 1000 + wardOfF(f)!!.w + 20)
        assertTrue(placeWarnings(f, listOf(w), room, walls, ws).any { it.key == "fz.doorsHit" })
        // dragged into the room and turned it stands on no wall
        val p = f.copy(pose = Pose("A", 2500, 900, 90))
        assertNull(footsOf(p, walls, ws).single().wall)
        assertTrue(placeWarnings(p, emptyList(), room, walls, ws).none { it.key == "fz.outside" })
        // a hung shelf is off the floor
        val sh = placed(piece("shelfW"), listOf("B"), "r", "w")
        footsOf(sh, walls, ws).single().let { assertFalse(it.floor); assertEquals(1500, it.lo) }
    }
}
