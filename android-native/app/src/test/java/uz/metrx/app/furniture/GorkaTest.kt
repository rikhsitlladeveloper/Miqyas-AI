package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** The guest room's gorka and the big dining table (Gorka.kt, modern 3D part 6a): boxes, parts, hardware, seats, prices. */
class GorkaTest {
    private val ws = Workshop()
    private fun piece(id: String, v: Map<String, Int> = emptyMap()) = pieceOf(fModel(id)!!, v, ws, id)
    private fun gorka(v: Map<String, Int> = emptyMap()) = piece("gorka", v)
    private fun hw(f: Furniture) = hardware(listOf(f), ws)

    /* ---------------- the gallery and the steps ---------------- */

    @Test fun bothAreInTheGuestRoomGroupWithTheirSteps() {
        val living = GALLERY.first { it.first == "living" }.second
        assertTrue("gorka" in living); assertTrue("dining12" in living)
        assertEquals(listOf("w", "h", "tw", "tv"), stepsOf(fModel("gorka")!!).map { it.key })
        assertEquals(listOf("w", "d", "h", "st", "lg", "tk"), stepsOf(fModel("dining12")!!).map { it.key })
        assertEquals(listOf(3000, 2100, 500, 1), stepsOf(fModel("gorka")!!).map { it.usual })
        assertEquals(listOf(2800, 1100, 760, 1, 0, 0), stepsOf(fModel("dining12")!!).map { it.usual })
        // what was asked comes back as asked, and both are newer models with parts, hardware and a price
        listOf("gorka", "dining12").forEach { id ->
            val f = piece(id)
            assertEquals("other", kindKey(f))
            val v = valsOf(f, ws)
            stepsOf(fModel(id)!!).forEach { s -> assertEquals("$id ${s.key}", s.usual, v[s.key]) }
            assertTrue(cutList(listOf(f), ws).isNotEmpty())
            assertEquals(id, 0, costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS).missing)
        }
        assertTrue(canStandFree(piece("dining12"))); assertFalse(canStandFree(gorka()))
        assertTrue(isItemPiece(piece("dining12"))); assertFalse(isItemPiece(gorka()))
    }

    /* ---------------- the gorka's boxes ---------------- */

    @Test fun theGorkaIsTwoTowersABaseABridgeAndAPanel() {
        val f = gorka()
        val r = gorkaRoles(f)!!
        assertEquals(2, r.lows.size); assertEquals(2, r.ups.size); assertNotNull(r.bridge); assertNotNull(r.panel)
        val (lo, up) = r.lows[0] to r.ups[0]
        // a tower: 500 × 400, its drawer box 500 high on a 60 plinth, the glass box on it up to 2100
        assertEquals(W_GAP_SIDE, lo.x); assertEquals(500, lo.w); assertEquals(GK_TOWER_D, lo.d); assertEquals(GK_LOW_H, lo.h); assertEquals(GK_PLINTH, wardBase(lo))
        assertEquals(lo.x, up.x); assertEquals(GK_LOW_H, up.elev); assertEquals(2100, up.elev + up.h)
        assertEquals("glass", up.sections.single().face); assertEquals(3, up.sections.single().inserts.count { it.kind == "glass" })
        assertEquals("R", up.sections.single().hinge); assertEquals("L", r.ups[1].sections.single().hinge)
        // the floating base between the towers: 2000 × 400 × 450, 220 off the floor, three drawers
        val b = r.base!!
        assertEquals(510, b.x); assertEquals(2000, b.w); assertEquals(GK_BASE_D, b.d); assertEquals(GK_BASE_ELEV, b.elev); assertTrue(hung(b))
        assertEquals(3, b.sections.size); assertTrue(b.sections.all { s -> s.fronts.kind == "open" && s.inserts.single().kind == "drawer" })
        // the bridge on top, 300 deep, its top level with the towers'
        val br = r.bridge!!
        assertEquals(b.x, br.x); assertEquals(b.w, br.w); assertEquals(2100, br.elev + br.h); assertEquals(GK_BRIDGE_D, br.d)
        // the panel 80 in from each tower, from the base's top to 20 under the bridge; the second tower after the base
        val p = r.panel!!
        assertEquals(590, p.x); assertEquals(1840, p.w); assertEquals(620, p.elev); assertEquals(1160, p.h); assertEquals("stone", p.opt!!.panel); assertEquals(65, p.opt!!.tv)
        assertEquals(2510, r.lows[1].x)
        assertEquals(3000, runLen(f)); assertEquals(W_GAP_SIDE, runStart(f))
        // the cabinets pass the wardrobe checks
        f.modules.filter { it.type == "wardrobe" }.forEach { m ->
            val c = wardrobeChecks(m, 3100, 2700, ws, emptyList(), emptyList())
            assertTrue("${boxRole(f, m)}: $c", c.none { it.level == "err" })
        }
        assertEquals(listOf("gk.box.low", "gk.box.tower", "gk.box.base", "gk.box.bridge", "gk.box.low", "gk.box.tower"),
            f.modules.filter { it.type == "wardrobe" }.map { boxRole(f, it) })
    }

    @Test fun oneTowerNoBridgeAndANarrowGorkaKeepTheNiche() {
        val f = pieceResized(gorka(), mapOf("one" to 1, "nobr" to 1), ws)
        val r = gorkaRoles(f)!!
        assertEquals(1, r.lows.size); assertNull(r.bridge)
        assertEquals(2500, r.base!!.w); assertEquals(3000, valsOf(f, ws)["w"])
        // with one tower the floating base is the run too
        assertEquals(3000, runLen(f))
        // the panel stops where a bridge would be
        assertEquals(2100 - GK_BRIDGE_H - GK_PANEL_GAP, r.panel!!.elev + r.panel!!.h)
        assertEquals(mapOf("one" to 1, "nobr" to 1), valsOf(f, ws).filterKeys { it == "one" || it == "nobr" })
        // back to two towers and a bridge
        val g = pieceResized(f, mapOf("one" to 0, "nobr" to 0), ws)
        assertEquals(6, g.modules.count { it.type == "wardrobe" })
        // 1800 wide: the towers give way so the niche stays 900
        val n = gorka(mapOf("w" to 1800))
        assertEquals(450, gorkaRoles(n)!!.lows[0].w); assertEquals(GK_NICHE_MIN, gorkaRoles(n)!!.base!!.w)
    }

    @Test fun aChangedBoxCarriesTheOthers() {
        val f = gorka()
        val r = gorkaRoles(f)!!
        // the first tower's drawer box made 600 wide: its glass box follows, the base and the second tower move on
        val wider = gorkaPack(f.copy(modules = f.modules.map { if (it.id == r.lows[0].id) it.copy(w = 600, sections = splitSections(600, it.sections)) else it }), r.lows[0].id, ws)
        val r2 = gorkaRoles(wider)!!
        assertEquals(600, r2.ups[0].w); assertEquals(610, r2.base!!.x); assertEquals(610, r2.bridge!!.x); assertEquals(2610, r2.lows[1].x); assertEquals(2610, r2.ups[1].x)
        assertEquals(690, r2.panel!!.x)
        // the bridge made narrower leads the base
        val br = gorkaPack(f.copy(modules = f.modules.map { if (it.id == r.bridge!!.id) it.copy(w = 1800, sections = splitSections(1800, it.sections)) else it }), r.bridge!!.id, ws)
        assertEquals(1800, gorkaRoles(br)!!.base!!.w); assertEquals(2310, gorkaRoles(br)!!.lows[1].x); assertEquals(1640, gorkaRoles(br)!!.panel!!.w)
        // a lower ceiling lowers the towers; the bridge stays level with them
        val low = fitTo(f, listOf("A"), { 3200 }, 2000, ws)
        val r3 = gorkaRoles(low)!!
        assertEquals(1980, r3.ups[0].elev + r3.ups[0].h); assertEquals(1980, r3.bridge!!.elev + r3.bridge!!.h)
    }

    @Test fun glassDoorsPanelAndTvChangeInPlace() {
        val f = gorka()
        val solid = withGorkaGlass(f, false)
        assertFalse(gorkaGlass(solid)); assertEquals(1, valsOf(solid, ws)["solid"])
        assertTrue(gorkaRoles(solid)!!.ups.all { u -> u.sections.single().inserts.all { it.kind == "shelf" } })
        assertTrue(gorkaGlass(withGorkaGlass(solid, true)))
        // the doors stay as they were when the gorka is built again (new sizes)
        assertEquals(1, valsOf(pieceResized(solid, mapOf("w" to 3200), ws), ws)["solid"])
        val slats = withGorkaPanel(f, panel = "slats", tv = 75)
        assertEquals("slats", gorkaRoles(slats)!!.panel!!.opt!!.panel); assertEquals(2, valsOf(slats, ws)["tv"])
        // a 75″ TV (1660 wide) fits the 1840 panel; an 85″ (1882) does not, nor a 55″ on the narrowest gorka
        assertTrue(tvFits(slats)); assertFalse(tvFits(withGorkaPanel(f, tv = 85)))
        assertFalse(tvFits(withGorkaPanel(gorka(mapOf("w" to 1800)), tv = 55)))
        assertEquals(1439 to 809, tvSize(65))
    }

    /* ---------------- parts and hardware ---------------- */

    @Test fun theGorkasPartsAndHardware() {
        val f = gorka()
        val parts = f.modules.flatMap { partsOf(it, ws) }
        // glass doors are bought, not cut: only the bridge's three doors are board doors
        assertEquals(3, parts.filter { it.key == "fp.door" }.sumOf { it.qty })
        // five drawers: one in each tower, three in the base; each with its box
        assertEquals(5, parts.filter { it.key == "fp.dFace" }.sumOf { it.qty })
        assertEquals(10, parts.filter { it.key == "fp.dSide" }.sumOf { it.qty })
        assertEquals(1, parts.filter { it.key == "gk.panelBack" }.sumOf { it.qty })
        val h = hw(f)
        // the towers' glass doors (497 × 1597) and glass shelves; hinges: 3 a tower door, 2 a bridge door
        assertEquals(2 * 497 * 1597, h["glassDoor"]); assertEquals(2 * 3 * (468 - 4) * (GK_TOWER_D - 25), h["glassShelf"])
        assertEquals(12, h["hingeSoft"]); assertEquals(5, h["runner"])
        // the glass doors open by a push latch; the drawers and the bridge's doors have handles
        assertEquals(2, h["push"]); assertEquals(8, h["handle"])
        // four boxes hang (the glass boxes on their drawer boxes, the base, the bridge)
        assertEquals(8, h["hanger"])
        // the panel's stone facing by the m²
        assertEquals(1840 * 1160, h["tvStone"]); assertNull(h["led"]); assertNull(h["cornice"])
        assertEquals(1840 * 1160, hw(withGorkaPanel(f, panel = "mould"))["tvMould"])
        assertEquals(1, cutList(listOf(withGorkaPanel(f, panel = "mould")), ws).count { it.p.key == "gk.panel" })
    }

    @Test fun ledAndTheNeoclassicCornice() {
        val f = withLook(gorka()) { it.copy(led = true) }
        val h = hw(f)
        // up both sides of each glass box, under the base and the bridge, one driver for every 5 m; no door sensors
        val mm = 2 * 2 * (1600 - 32) + (2000 - 80) + (2000 - 60)
        assertEquals(mm, gorkaLedMm(f, ws)); assertEquals(mm, h["led"]); assertEquals(3, h["ledPsu"]); assertNull(h["ledSensor"])
        // the neoclassic preset: milled fronts and the cornice on the towers and the bridge
        val neo = withPreset(gorka(), "neo", fresh = true)
        assertEquals("cornice", neo.look!!.crown); assertEquals("shaker", neo.look!!.style)
        val hn = hw(neo)
        assertEquals(500 + 500 + 2000, hn["cornice"]); assertTrue((hn["frontShaker"] ?: 0) > 0)
        // a modern preset has none
        assertNull(hw(withPreset(gorka(), "twotone", fresh = true))["cornice"])
        assertEquals("", withPreset(neo, "dark").look!!.crown)
    }

    @Test fun theGorkaIsPricedWithItsOptions() {
        val f = withLook(withGorkaPanel(gorka(), panel = "slats")) { it.copy(led = true, crown = "cornice") }
        val c = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(0, c.missing)
        val keys = c.lines.filter { it.group == "hw" }.map { it.key }
        listOf("tvSlats", "led", "ledPsu", "cornice", "glassDoor", "glassShelf", "runner", "hingeSoft").forEach { assertTrue(it, it in keys) }
        val slats = c.lines.single { it.key == "tvSlats" }
        assertEquals(2.14, slats.qty, 1e-9)   // 1840 × 1160 = 2,1344 m², up to 0,01
        assertEquals(java.math.BigInteger.valueOf(Math.round(2.14 * 550000)), slats.amount)
        assertTrue(c.total > costOf(listOf(gorka()), ws, MAT_PRESETS, HW_PRESETS).total)
    }

    /* ---------------- the big dining table ---------------- */

    @Test fun theBigTableSeatsTwelveOrTen() {
        val f = piece("dining12")
        val m = wardOfF(f)!!
        assertEquals("table", m.type); assertEquals(2800, m.w); assertEquals(1100, m.d); assertEquals(760, m.h); assertEquals(12, m.opt!!.seats)
        val cs = chairPlaces(m)
        assertEquals(12, cs.size); assertEquals(12, seatsOf(m))
        // five a side, one at each end
        assertEquals(5, cs.count { it.face == "+n" }); assertEquals(5, cs.count { it.face == "-n" }); assertEquals(1, cs.count { it.face == "+a" }); assertEquals(1, cs.count { it.face == "-a" })
        fun spacing(c: List<Chair>) = c.filter { it.face == "+n" }.map { it.a }.sorted().zipWithNext { a, b -> b - a }
        assertEquals(listOf(540, 540, 540, 540), spacing(cs))
        // the side chairs stay within the table's length, centred, out from its edges
        val side = cs.filter { it.face == "+n" }
        assertTrue(side.minOf { it.a } - DT_CHAIR_W / 2 >= 0 && side.maxOf { it.a } + DT_CHAIR_W / 2 <= m.w)
        assertEquals(m.w, side.minOf { it.a } + side.maxOf { it.a })
        assertTrue(cs.filter { it.face == "+n" }.all { it.n == -DT_CHAIR_OUT }); assertTrue(cs.filter { it.face == "-n" }.all { it.n == m.d + DT_CHAIR_OUT })
        // ten: four a side, further apart
        val ten = wardOfF(pieceResized(f, mapOf("st" to 0), ws))!!
        assertEquals(10, seatsOf(ten)); assertEquals(listOf(620, 620, 620), spacing(chairPlaces(ten)))
        // a table too short for twelve takes fewer, never closer than the pitch
        val short = wardOfF(pieceResized(f, mapOf("w" to 1800), ws))!!
        assertEquals(12, short.opt!!.seats); assertEquals(8, seatsOf(short))
        assertTrue(spacing(chairPlaces(short)).all { it >= DT_PITCH })
        // an ordinary dining table has no chairs
        assertTrue(chairPlaces(wardOfF(piece("dining"))!!).isEmpty())
    }

    @Test fun theBigTablesPartsHardwareAndPrice() {
        val f = piece("dining12")
        val m = wardOfF(f)!!
        val parts = partsOf(m, ws)
        // two panel legs of two boards each, a rail between them; the top is worktop board, not cut
        assertEquals(4, parts.filter { it.key == "fp.tLeg" }.sumOf { it.qty }); assertEquals(1, parts.filter { it.key == "fp.apron" }.sumOf { it.qty })
        assertTrue(parts.none { it.key == "fp.top" })
        assertEquals(2, topStrips(m)); assertEquals(5600, itemWorktopMm(m))
        val h = hw(f)
        assertEquals(16, h["confirmat"]); assertEquals(1, h["wtJoint"]); assertNull(h["tableLeg"])
        val c = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(0, c.missing)
        val wt = c.lines.single { it.key == "wt38m" }
        assertEquals(5.6, wt.qty, 1e-9); assertEquals(java.math.BigInteger.valueOf(5_6 * 420000L / 10), wt.amount)
        // metal legs and a wood top
        val g = pieceResized(f, mapOf("lg" to 1, "tk" to 1), ws)
        assertEquals("metal4", wardOfF(g)!!.opt!!.legs); assertEquals("wt38h", g.mats.top); assertEquals(1, valsOf(g, ws)["tk"]); assertEquals(1, valsOf(g, ws)["lg"])
        assertEquals(4, hw(g)["tableLeg"]); assertEquals(8, hw(g)["confirmat"])
        assertTrue(costOf(listOf(g), ws, MAT_PRESETS, HW_PRESETS).lines.any { it.key == "wt38h" })
        // back to stone keeps a stone decor
        assertEquals("wt38m", pieceResized(g, mapOf("tk" to 0), ws).mats.top)
        assertEquals("wt38o", dtTop("stone", "wt38o")); assertEquals("wt38c", dtTop("wood", "wt38c"))
        // its designer's sizes
        assertEquals(1800..3600, itemRange(m, "w")); assertEquals(900..1300, itemRange(m, "d"))
        // an older dining table is priced as before
        assertEquals(1400, itemWorktopMm(wardOfF(piece("dining", mapOf("tp" to 1)))!!))
    }

    /* ---------------- strings ---------------- */

    @Test fun everyNewStringIsInFourLanguages() {
        val file = listOf(File("src/main/assets/strings.json"), File("app/src/main/assets/strings.json")).first { it.exists() }
        val all = kotlinx.serialization.json.Json.parseToJsonElement(file.readText()) as kotlinx.serialization.json.JsonObject
        val keys = listOf("ft.gorka", "fz.m.gorka", "fz.s.gorka", "ft.dining12", "fz.m.dining12", "fz.s.dining12", "gk.tw", "gk.tw.h", "gk.tv", "gk.tv.h",
            "gk.box.low", "gk.box.tower", "gk.box.base", "gk.box.bridge", "gk.panel", "gk.panelBack", "gk.title", "gk.towers", "gk.towers.1", "gk.towers.2",
            "gk.bridge", "gk.rebuild", "gk.glass", "gk.led", "gk.cornice", "gk.panelT", "gk.tvFits", "gk.tvWide", "dt.st", "dt.st.h", "dt.tk", "dt.tk.h",
            "dt.seated", "dt.short", "dt.fabric", "dt.chairsNote") +
            GK_PANELS.flatMap { listOf("gk.pn.$it", "gk.pn.$it.s") } + GK_TVS.flatMap { listOf("gk.tv.$it", "gk.tv.$it.s") } +
            DT_SEATS.flatMap { listOf("dt.st.$it", "dt.st.$it.s") } + listOf("stone", "wood").flatMap { listOf("dt.tk.$it", "dt.tk.$it.s") } +
            listOf("tvStone", "tvSlats", "tvMould").flatMap { listOf("hk.$it", "hp.$it") }
        keys.forEach { k ->
            val v = all[k] as? kotlinx.serialization.json.JsonArray
            assertNotNull(k, v); assertEquals(k, 4, v!!.size)
            // Uzbek with the ‘ (U+2018), never a plain apostrophe
            assertFalse(k, v[0].toString().contains('\'') || v[0].toString().contains('ʻ'))
        }
    }
}
