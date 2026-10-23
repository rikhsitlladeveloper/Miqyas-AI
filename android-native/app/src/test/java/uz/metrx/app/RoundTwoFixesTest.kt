package uz.metrx.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Feature
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Project
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.Snap
import uz.metrx.app.data.SnapRoom
import uz.metrx.app.data.Store
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.putBack
import uz.metrx.app.data.roomsByWorkspace
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.furniture.HW_PRESETS
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.NO_HANDLES
import uz.metrx.app.furniture.Remnant
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.canUndoCut
import uz.metrx.app.furniture.commonHandle
import uz.metrx.app.furniture.costOf
import uz.metrx.app.furniture.cutDone
import uz.metrx.app.furniture.extrasParts
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.hasHandles
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.pieceResized
import uz.metrx.app.furniture.pieceVals
import uz.metrx.app.furniture.remnantsFor
import uz.metrx.app.furniture.removable
import uz.metrx.app.furniture.shelfSpanMax
import uz.metrx.app.furniture.shelfTooLong
import uz.metrx.app.furniture.swapAll
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.polyDims
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.geo.readingLimit
import uz.metrx.app.plumb.PlFree
import uz.metrx.app.plumb.PlumbOrder
import uz.metrx.app.plumb.calcOf
import uz.metrx.app.plumb.needsRiser
import uz.metrx.app.plumb.riserToPlace
import uz.metrx.app.report.fingerprint
import uz.metrx.app.tiles.TSurf
import uz.metrx.app.tiles.TileCount
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.TileNeed
import uz.metrx.app.tiles.surfHeightsOk
import uz.metrx.app.win.WCell
import uz.metrx.app.win.WCol
import uz.metrx.app.win.minSize
import uz.metrx.app.win.newItem
import uz.metrx.app.win.wkind

/** The round-two fixes of 24 Oct 2026 (bug list B, Z and T items) that change numbers or rules. */
class RoundTwoFixesTest {
    private fun dims(a: Int, b: Int, h: Int = 2700) = mapOf("A" to Dim(a), "B" to Dim(b), "H" to Dim(h), "T" to Dim(200, "default"))

    /* ---------------- B4: each drawn room keeps its own snap ---------------- */

    // a drawn room a little off square, measured as a 4 × 3 m rectangle: snapped it closes, not snapped it does not
    private val skew = listOf(Pt(0.0, 0.0), Pt(4000.0, 150.0), Pt(4000.0, 3000.0), Pt(0.0, 3000.0))
    private fun drawn(id: String, snap: Boolean?) = Room(id, "w", "X", template = "poly", shape = "poly",
        dims = polyDims(4) + mapOf("A" to Dim(4000, "manual"), "B" to Dim(3000, "manual"), "C" to Dim(4000, "manual"), "D" to Dim(3000, "manual"), "H" to Dim(2700, "manual")),
        poly = Poly(skew, snap = snap))

    @Test fun aDrawnRoomIsSolvedWithItsOwnSnapWhateverTheSetting() {
        assertTrue(polyGeo(drawn("a", true), false).solved)
        assertFalse(polyGeo(drawn("b", false), true).solved)
        // a room with none (an old quote's) takes the one it is given
        assertTrue(polyGeo(drawn("c", null), true).solved)
        assertFalse(polyGeo(drawn("d", null), false).solved)
        assertEquals(areas(drawn("e", true), false), areas(drawn("f", null), true))
    }

    @Test fun roomsSavedWithoutASnapTakeTheSettingOnce() {
        val p = Project("p", "T", rooms = listOf(drawn("a", null), drawn("b", true), Room("r", "w", "R", dims = dims(4000, 3000))))
        val q = Store.withSnap(p, false)
        assertEquals(listOf(false, true, null), q.rooms.map { it.poly?.snap })
        assertSame(q, Store.withSnap(q, true))
    }

    /* ---------------- B10: a tray reading keeps the typed limits ---------------- */

    @Test fun aReadingBelowTheLeastIsRefused() {
        assertEquals("err.min" to 1800, readingLimit("H", 1000, false))
        assertEquals("err.min" to 500, readingLimit("A", 300, false))
        assertNull(readingLimit("A", 300, true))
        assertEquals("err.max" to 6000, readingLimit("H", 7000, false))
        assertNull(readingLimit("H", 2700, false))
    }

    /* ---------------- B11 / corner columns ---------------- */

    @Test fun aColumnInACornerAddsNoWall() {
        val r = Room("r", "w", "X", dims = dims(5000, 4000, 3000))
        val mid = areas(r.copy(features = listOf(Feature("c", "column", "A", 1000, 400, 300))))!!
        assertEquals(18_000L + 600, mid.perim)
        // flush with corner 1: its side against wall D covers that much of D, so the walls stay 18 m
        val corner = areas(r.copy(features = listOf(Feature("c", "column", "A", 0, 400, 300))))!!
        assertEquals(18_000L, corner.perim); assertEquals(18_000L * 3000, corner.gross)
        // the floor the plan cards show is the same, less the column
        assertEquals(20_000_000L - 400L * 300, corner.floor)
    }

    /* ---------------- B13 and B4: the fingerprint of quotes issued before ---------------- */

    private fun snapOf(rooms: List<Room>, snap: Boolean = true, calc: List<Room> = emptyList(), elec: ElecOrder? = null, tiles: List<TileLayout>? = null) =
        Snap("Order", rooms = rooms.map { SnapRoom(it, "W") }, snap = snap, calcRooms = calc.map { SnapRoom(it, "W") }, elec = elec, tiles = tiles)

    @Test fun aRoomsOwnSnapKeepsAnOlderQuoteMatching() {
        val old = fingerprint(snapOf(listOf(drawn("a", null))))
        assertEquals(old, fingerprint(snapOf(listOf(drawn("a", true)))))
        // the setting turned off later: the rooms drawn with it on still match
        assertEquals(old, fingerprint(snapOf(listOf(drawn("a", true)), snap = false)))
        // an older quote made with it off still matches its rooms kept off
        assertEquals(fingerprint(snapOf(listOf(drawn("a", null)), snap = false)), fingerprint(snapOf(listOf(drawn("a", false)), snap = true)))
        // a room drawn the other way than the rest is not the same
        assertNotEquals(fingerprint(snapOf(listOf(drawn("a", true), drawn("b", null)))), fingerprint(snapOf(listOf(drawn("a", true), drawn("b", false)))))
    }

    @Test fun roomsLeftOutCountOnlyWithTheTradesThingsInThem() {
        val shown = Room("s", "w", "S", dims = dims(4000, 3000)); val out = Room("o", "w", "O", dims = dims(3000, 3000))
        val inShown = ElecOrder(listOf(ElecDev("d", "s1", "s", "A", 1000, 300)))
        assertEquals(fingerprint(snapOf(listOf(shown), elec = inShown)), fingerprint(snapOf(listOf(shown), calc = listOf(out), elec = inShown)))
        val inOut = ElecOrder(listOf(ElecDev("d", "s1", "o", "A", 1000, 300)))
        assertNotEquals(fingerprint(snapOf(listOf(shown), elec = inOut)), fingerprint(snapOf(listOf(shown), calc = listOf(out), elec = inOut)))
    }

    @Test fun theTileLayoutsAreInTheFingerprint() {
        val r = Room("s", "w", "S", dims = dims(4000, 3000))
        assertEquals(fingerprint(snapOf(listOf(r))), fingerprint(snapOf(listOf(r), tiles = emptyList())))
        val l = TileLayout("l", roomId = "s")
        assertNotEquals(fingerprint(snapOf(listOf(r), tiles = listOf(l))), fingerprint(snapOf(listOf(r), tiles = listOf(l.copy(pattern = "diag")))))
    }

    @Test fun aTradesThingsAreInTheFingerprintAndOlderQuotesStillMatch() {
        val r = Room("s", "w", "S", dims = dims(4000, 3000))
        val sn = snapOf(listOf(r), elec = ElecOrder(listOf(ElecDev("d", "s1", "s", "A", 1000, 300))))
        val moved = snapOf(listOf(r), elec = ElecOrder(listOf(ElecDev("d", "s1", "s", "A", 1500, 300))))
        assertNotEquals(fingerprint(sn), fingerprint(moved))
        // a quote issued before (its fingerprint without the trade's part) still matches its unchanged draft
        val older = fingerprint(sn.copy(elec = null))
        assertTrue(uz.metrx.app.report.sameAsQuote(sn, older))
        assertTrue(uz.metrx.app.report.sameAsQuote(sn, fingerprint(sn)))
        assertFalse(uz.metrx.app.report.sameAsQuote(moved, fingerprint(sn)))
    }

    @Test fun anOlderQuoteSaysBothNameAndArea() {
        val sn = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }.decodeFromString(Snap.serializer(), """{"name":"x"}""")
        assertEquals("both", sn.roomLabel)
    }

    /* ---------------- Z1 / Z2: handles ---------------- */

    private val ws = Workshop()
    private fun piece(id: String) = pieceOf(fModel(id)!!, emptyMap(), ws, id)

    @Test fun changeForAllHandlesStayWhenAPieceOfSeveralBoxesIsResized() {
        val st = swapAll(listOf(piece("stenka")), handle = "handleKnob").single()
        val w = pieceVals(st, ws).getValue("w")
        val big = pieceResized(st, mapOf("w" to w + 400), ws)
        assertEquals("handleKnob", big.handle); assertEquals("handleKnob", commonHandle(listOf(big)))
        val none = swapAll(listOf(st), handle = NO_HANDLES).single()
        assertFalse(hasHandles(pieceResized(none, mapOf("w" to w + 400), ws)))
    }

    @Test fun noHandlesIsSeenWithAFridgeSpaceInTheKitchen() {
        val k = piece("L").let { it.copy(modules = it.modules + Module("g", "gap", 600, 2000, 650, wall = it.modules.first().wall, fronts = Fronts("open", 0), legs = false, app = "fridge")) }
        val none = swapAll(listOf(k), handle = NO_HANDLES)
        assertEquals(NO_HANDLES, commonHandle(none))
        assertFalse(hasHandles(none.single()))
        assertTrue(hasHandles(k))
    }

    /* ---------------- Z3 / Z4 / Z5: remnants ---------------- */

    @Test fun aTakenRemnantStaysTakenAndLocked() {
        val store = listOf(Remnant("t", "ldsp16w", 800, 500, src = "o0", used = "gone"), Remnant("f", "ldsp16w", 800, 500, src = "o0"))
        // the order that took it was deleted: still not free
        assertEquals(listOf("f"), remnantsFor(store, "o2", false).map { it.id })
        assertFalse(removable(store[0])); assertTrue(removable(store[1]))
    }

    @Test fun anOrdersCutIsNotUndoneOnceAnotherTookItsOffcutAndNoneIsAddedTwice() {
        var n = 0
        val ids = { "r${++n}" }
        val f = piece("dresser")
        val lays = costOf(listOf(f), ws, uz.metrx.app.furniture.MAT_PRESETS, HW_PRESETS).layouts
        val cut = cutDone(emptyList(), lays, uz.metrx.app.furniture.MAT_PRESETS, "o1", 300, 1, ids)
        val mine = cut.filter { it.src == "o1" }
        assertTrue(mine.isNotEmpty()); assertTrue(canUndoCut(cut, "o1"))
        // another order takes one of them
        val taken = cut.map { if (it.id == mine[0].id) it.copy(used = "o2") else it }
        assertFalse(canUndoCut(taken, "o1"))
        // cut again (as after an Undo that was refused before): the taken one is not made a second time
        val again = cutDone(taken, lays, uz.metrx.app.furniture.MAT_PRESETS, "o1", 300, 2, ids)
        assertEquals(cut.size, again.size)
        assertEquals(1, again.count { it.mat == mine[0].mat && it.L == mine[0].L && it.W == mine[0].W && it.used == "o2" })
    }

    /* ---------------- Z6 / Z10 ---------------- */

    @Test fun endPanelsBelongToNoModule() {
        val k = piece("L").let { it.copy(kx = uz.metrx.app.furniture.KExtras(ends = 2, endsUp = 1)) }
        assertTrue(extrasParts(k, ws).isNotEmpty())
        assertTrue(extrasParts(k, ws).all { it.mod == "" })
    }

    @Test fun oneShelfRuleForTheDesignerAndTheCheckList() {
        assertEquals(1100, shelfSpanMax(18)); assertEquals(1000, shelfSpanMax(16))
        assertFalse(shelfTooLong(1050, 18)); assertTrue(shelfTooLong(1050, 16))
        assertFalse(shelfTooLong(1102, 18)); assertTrue(shelfTooLong(1103, 18))
    }

    /* ---------------- T1: a typed-room-only plumber's order ---------------- */

    @Test fun aTypedRoomOnlyOrderIsNotAskedForARiser() {
        val p = Project("p", "T", industry = "plumb", plumb = PlumbOrder(free = listOf(PlFree("f", "@sx.k.bath"))))
        assertTrue(needsRiser(p))
        assertNull(riserToPlace(p, true))
        assertTrue(calcOf(p, true).warns.none { it.key == "sx.w.noRiser" })
    }

    @Test fun anOlderTypedRoomTakesItsKitsChoices() {
        val f = PlFree("f", "", "bath", shower = 1, bath = 0, kit = "bt.cabin")
        assertTrue(uz.metrx.app.plumb.withKit(f).cabin)
        assertFalse(uz.metrx.app.plumb.withKit(f.copy(kept = true)).cabin)
    }

    /* ---------------- T2 / T4: tiles ---------------- */

    @Test fun aWallHeightTypedWrongIsNotSaved() {
        assertTrue(surfHeightsOk(TSurf("A")))
        assertFalse(surfHeightsOk(TSurf("A", "to", h1 = 0))); assertTrue(surfHeightsOk(TSurf("A", "to", h1 = 1500)))
        assertFalse(surfHeightsOk(TSurf("A", "band", h0 = 900, h1 = 0))); assertFalse(surfHeightsOk(TSurf("A", "band", h0 = 0, h1 = 1500)))
        assertTrue(surfHeightsOk(TSurf("A", "band", h0 = 900, h1 = 1500)))
    }

    @Test fun theSameTileAtTwoPricesIsTwoLines() {
        fun need(price: String) = TileNeed("plain", 300, 600, 10, 2, 0, 12, 0, 10, 14, 8, 2, 2.0, price)
        assertEquals(2, (TileCount(listOf(need("100"))) + TileCount(listOf(need("200")))).needs.size)
        assertEquals(1, (TileCount(listOf(need("100"))) + TileCount(listOf(need("100")))).needs.size)
    }

    /* ---------------- T5 / T8 / T9 ---------------- */

    @Test fun undoPutsBackOnlyTheDeletedItem() {
        assertEquals(listOf("a", "b", "c"), listOf("a", "c").putBack("b", 1))
        assertEquals(listOf("a", "x"), listOf("a").putBack("x", 5))
    }

    @Test fun aWindowIsNotMadeSmallerThanItsSashesTake() {
        val w3 = newItem("w", wkind("w3"))
        assertEquals(450 to 300, minSize(w3))
        val tall = w3.copy(cols = listOf(WCol(700, listOf(WCell(400), WCell(400), WCell(400)))))
        assertEquals(300 to 450, minSize(tall))
    }

    @Test fun theNextStepSeesEveryRoomOfAWorkspace() {
        val p = Project("p", "T", floors = listOf(Workspace("w1", "1"), Workspace("w2", "2")),
            rooms = listOf(Room("a", "w1", "A"), Room("b", "w1", "B"), Room("c", "w2", "C")))
        assertEquals(listOf("a", "b", "c"), roomsByWorkspace(p).map { it.second.id })
    }

    /* ---------------- T10: typed electric rooms keep the kit's lights ---------------- */

    @Test fun aTypedRoomKeepsItsWallLightsStripsAndSocketHeights() {
        val bath = uz.metrx.app.elec.kitOf("bt.std")!!
        val f = uz.metrx.app.elec.freeOf(bath, uz.metrx.app.elec.defaultOpts(bath), "b", "", 2500, 2000, 2700)
        assertEquals(listOf("lw"), f.lamps)
        assertTrue(f.sockH.contains(1000))
        val p = Project("p", "T", industry = "elec", elec = ElecOrder(free = listOf(f)))
        val c = uz.metrx.app.elec.ctxs(p, true).single()
        val ds = uz.metrx.app.elec.devsIn(p, c)
        assertEquals(1, ds.count { it.t == "lw" })
        assertTrue(ds.any { it.t == "sw" && it.h == 1000 })
        val kit = uz.metrx.app.elec.kitOf("kt.std")!!
        val k = uz.metrx.app.elec.freeOf(kit, uz.metrx.app.elec.defaultOpts(kit), "k", "", 4000, 3000, 2700)
        assertEquals(listOf("led"), k.lamps)
        val pk = Project("p", "T", industry = "elec", elec = ElecOrder(free = listOf(k)))
        assertEquals(1, uz.metrx.app.elec.devsIn(pk, uz.metrx.app.elec.ctxs(pk, true).single()).count { it.t == "led" })
    }
}
