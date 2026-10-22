package uz.metrx.app.tiles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.trades.TradeSet

/** The tiler's layouts on the 5 × 4 × 3 m room with a door 900 × 2100 on wall A and a window 1200 × 1500 at 900 on wall C. */
class TilesTest {
    private val room = Room("r", "w", "Hammom", dims = mapOf("A" to Dim(5000), "B" to Dim(4000), "H" to Dim(3000), "T" to Dim(200, "default")),
        openings = listOf(Opening("d", "door", "A", 900, 2100, 500), Opening("o", "window", "C", 1200, 1500, 1900, 900)))
    private fun geo(fixes: List<TFix> = emptyList()) = roomGeo(room, true, fixes)!!
    private fun floor(a: Int, b: Int, pattern: String = "straight", start: String = "corner", joint: Int = 0, rot: Int = 0) =
        TileLayout("f", pattern = pattern, a = a, b = b, joint = joint, start = start, rot = rot, roomId = "r", surfs = listOf(TSurf("floor")), look = "white")

    @Test fun wholeTilesFillAnExactFloor() {
        val laid = layRoom(floor(500, 500), geo(), null)
        assertEquals(80, laid.pieces.size)
        assertTrue(laid.pieces.none { it.cut })
        assertEquals(20e6, laid.pieces.sumOf { it.area }, 1.0)
    }

    @Test fun cutsOffcutsSpareAndBoxes() {
        val l = floor(600, 600)
        val c = countLaid(l, layRoom(l, geo(), null))
        val n = c.needs.single()
        assertEquals(48, n.whole)                       // 8 × 6 whole tiles
        assertEquals(15, n.cut)                         // 6 down the side, 8 along the far wall, 1 in the corner
        assertEquals(3, n.reused)                       // the side's 200 mm strips: two from a tile
        assertEquals(60, n.tiles)
        assertEquals(63, n.withSpare)                   // + 5 %
        assertEquals(4, n.perBox)
        assertEquals(16, n.boxes)
        assertEquals(20.0, c.m2, 1e-6)
    }

    @Test fun spareIsTenForDiagonalAndHerringbone() {
        assertEquals(5, spareOf(floor(300, 300)))
        assertEquals(10, spareOf(floor(300, 300, "diagonal")))
        assertEquals(10, spareOf(floor(200, 600, "herring")))
        assertEquals(10, spareOf(floor(300, 600, rot = 45)))
        assertEquals(7, spareOf(floor(300, 300).copy(spare = 7)))
    }

    @Test fun diagonalAndHerringboneCoverTheFloorOnce() {
        // with no joint every patch of floor is under exactly one tile: no gaps, no overlaps
        for (l in listOf(floor(300, 300, "diagonal", "center"), floor(200, 600, "herring", "center"), floor(300, 600, "brick2", "center"), floor(200, 600, "brick3"),
                floor(300, 600, rot = 45), floor(300, 300, "chess", "center"))) {
            val laid = layRoom(l, geo(), null)
            assertEquals(l.pattern + " " + l.rot, 20e6, laid.pieces.sumOf { it.area }, 20.0)
            assertTrue(laid.pieces.any { it.cut })
        }
        // a herringbone's tiles lie two ways
        val h = layRoom(floor(200, 600, "herring", "center"), geo(), null)
        assertTrue(h.pieces.any { it.vert } && h.pieces.any { !it.vert })
        // the chessboard's second look
        assertTrue(layRoom(floor(300, 300, "chess"), geo(), null).pieces.any { it.prod == 1 })
    }

    @Test fun jointsMakeRoomBetweenTiles() {
        val laid = layRoom(floor(600, 600, joint = 3), geo(), null)
        val whole = laid.pieces.filter { !it.cut }
        assertEquals(600.0 * 600, whole.first().area, 1e-6)
        // tiles + joints: the tiles cover less than the floor
        assertTrue(laid.pieces.sumOf { it.area } < 20e6 - 1e5)
    }

    @Test fun doorsAndWindowsAreLeftOut() {
        val a = TileLayout("w", place = "wall", a = 500, b = 500, joint = 0, start = "corner", roomId = "r", surfs = listOf(TSurf("A")))
        assertEquals(5000.0 * 3000 - 900.0 * 2100, layRoom(a, geo(), null).pieces.sumOf { it.area }, 10.0)
        // up to 1,5 m on wall C: the window's part below that line goes
        val c = a.copy(surfs = listOf(TSurf("C", "to", h1 = 1500)))
        assertEquals(5000.0 * 1500 - 1200.0 * 600, layRoom(c, geo(), null).pieces.sumOf { it.area }, 10.0)
        // a 600 backsplash band from 900 on wall C: the window from 900 to 2400 takes 1200 × 600 of it
        val band = a.copy(surfs = listOf(TSurf("C", "band", 900, 1500)))
        assertEquals(5000.0 * 600 - 1200.0 * 600, layRoom(band, geo(), null).pieces.sumOf { it.area }, 10.0)
    }

    @Test fun skirtingSkipsDoorsAndTiledWalls() {
        val f = floor(600, 600).copy(skirt = 100)
        assertEquals(18000.0 - 900, skirtRuns(f, geo(), listOf(f)).sumOf { it.len }, 1e-6)
        val w = TileLayout("w", place = "wall", roomId = "r", surfs = listOf(TSurf("B")))
        assertEquals(18000.0 - 900 - 4000, skirtRuns(f, geo(), listOf(f, w)).sumOf { it.len }, 1e-6)
        // skirting is cut from the tile: 600 × 100 strips, six from a 600 tile (with the cut)
        val c = countLayout(Project("p", "", rooms = listOf(room), tiles = listOf(f)), f, true)
        assertEquals(17.1, c.skirtM, 1e-9)
        assertTrue(c.needs.single().skirtTiles in 4..6)
    }

    @Test fun waterproofingFloorWallsAndShower() {
        val tray = TFix("t", "tray", "A", 0, 900, 900, 150)
        val g = geo(listOf(tray))
        // the tray in the corner of walls A and D
        assertNotNull(coverOn(g, g.wall("D")!!, tray))
        val wp = wpM2(TileRoom("r", listOf(tray), wp = true, wpUp = 200, showerH = 1800), g)
        assertEquals(20.0 + (18000 - 900) * 200 / 1e6 + 2 * 900 * 1600 / 1e6, wp, 1e-9)
    }

    @Test fun tilesStopRoundTheBathAndItsFrontIsTiled() {
        val bath = TFix("b", "bath", "B", 0, 1700, 700, 600)
        val g = geo(listOf(bath))
        val l = TileLayout("w", place = "bath", a = 500, b = 500, joint = 0, roomId = "r", surfs = listOf(TSurf("B"), TSurf("bath:b")))
        val laid = layRoom(l, g, null)
        val onWall = laid.pieces.filter { laid.surfs[it.s].key == "B" }.sumOf { it.area }
        val front = laid.pieces.filter { laid.surfs[it.s].key == "bath:b" }.sumOf { it.area }
        assertEquals(4000.0 * 3000 - 1700.0 * 600, onWall, 10.0)
        assertEquals(1700.0 * 600, front, 10.0)
        // the floor goes round it too
        assertEquals(20e6 - 1700.0 * 700, layRoom(floor(500, 500), g, null).pieces.sumOf { it.area }, 10.0)
    }

    @Test fun cornerProfilesRoundTheWindow() {
        val w = TileLayout("w", place = "wall", roomId = "r", profiles = true, surfs = listOf(TSurf("C")))
        assertEquals(2 * 1500.0 + 1200 + 1200, profileMm(w, geo()), 1e-9)
        assertEquals(0.0, profileMm(w.copy(profiles = false), geo()), 1e-9)
    }

    @Test fun aSurfaceWithoutARoom() {
        val l = TileLayout("p", a = 600, b = 600, joint = 0, start = "corner", panel = TPanel("floor", 3000, 2000))
        val c = countLayout(Project("p", ""), l, true)
        val n = c.needs.single()
        assertEquals(15, n.whole)
        assertEquals(5, n.cut)
        assertEquals(2, n.reused)
        assertEquals(18, n.tiles)
        assertEquals(6.0, c.m2, 1e-9)
        // and it can be drawn as a flat panel with its tiles
        val shell = panelScene(l)!!
        assertTrue(shell.parts.any { it.tile && it.faces.size >= 15 })
        assertNotNull(panelScene(l.copy(panel = TPanel("apron", 2400, 600))))
    }

    @Test fun roomPartsAndRows() {
        val f = floor(600, 600, joint = 2)
        val w = TileLayout("w", place = "wall", a = 300, b = 600, look = "carrara", roomId = "r", surfs = listOf(TSurf("A"), TSurf("B")))
        val p = Project("p", "", rooms = listOf(room), tiles = listOf(f, w), troom = listOf(TileRoom("r", wp = true)))
        val parts = tileParts(p.tiles, geo(), p.tiles)
        assertTrue(parts.isNotEmpty() && parts.all { it.tile })
        // a drawn look varies from tile to tile; a cut piece is a shade off
        assertTrue(parts.map { it.rgb }.distinct().size >= 4)
        val rows = tileRows(p, TradeSet(), true) { k, v -> k + v.values.joinToString(",", "(", ")") }
        assertEquals(listOf("t-tile0", "t-tile1", "t-glue", "t-grout", "t-wp"), rows.mats.map { it.id })
        assertEquals(listOf("t-lab", "t-labWp"), rows.labor.map { it.id })
        assertTrue(rows.mats[0].name.contains("~tl.lk.white"))
    }

    @Test fun tooManyTilesAreNotWorkedOut() {
        val laid = layRoom(floor(10, 10), geo(), null)
        assertTrue(laid.tooMany.isNotEmpty())
        assertTrue(countLaid(floor(10, 10), laid).tooMany)
    }

    @Test fun clippingKeepsAreas() {
        val sq = listOf(V2(0.0, 0.0), V2(100.0, 0.0), V2(100.0, 100.0), V2(0.0, 100.0))
        val hole = listOf(V2(20.0, 20.0), V2(40.0, 20.0), V2(40.0, 40.0), V2(20.0, 40.0))
        assertEquals(10000.0 - 400, subtract(sq, hole).sumOf { kotlin.math.abs(area(it)) }, 1e-6)
        val l = listOf(V2(0.0, 0.0), V2(300.0, 0.0), V2(300.0, 150.0), V2(600.0, 150.0), V2(600.0, 500.0), V2(0.0, 500.0))
        val parts = convexParts(l)
        assertTrue(parts.all { isConvex(it) })
        assertEquals(kotlin.math.abs(area(l)), parts.sumOf { kotlin.math.abs(area(it)) }, 1e-6)
    }
}
