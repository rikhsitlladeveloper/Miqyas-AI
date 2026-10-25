package uz.metrx.app.furniture

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger

/** The design data, presets, options and their prices (modern 3D part 2, 25 Oct 2026; Look.kt, Decors.kt). */
class LookTest {
    private val ws = Workshop()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun kitchen(layout: String = "I", sides: List<Int> = listOf(3000), island: Int = 0) =
        newFreeKitchen("Oshxona 1", layout, layout, sides, island, 2700, ws).copy(id = "k")

    /** A kitchen of one base unit with doors, a drawer unit, a wall unit and a tall pantry. */
    private fun units() = Furniture("u", "kitchen", modules = listOf(
        template("base", ws, "A", 600).copy(id = "b", x = 0),
        template("drawers", ws, "A", 600).copy(id = "d", x = 600),
        template("wall", ws, "A", 600).copy(id = "w", x = 0),
        template("pantry", ws, "A", 600).copy(id = "t", x = 1200)), walls = listOf("A"))

    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }

    /* ---------------- older orders ---------------- */

    @Test fun anOlderOrderLoadsAndSavesByteForByte() {
        val old = """{"id":"f1","kind":"kitchen","name":"Oshxona 1","roomId":null,"walls":[],"modules":[{"id":"m1","type":"base","w":600,"h":720,"d":560,"x":0,"wall":null,"elev":0,""" +
            """"fronts":{"kind":"door","n":2},"inserts":[],"sections":[],"legs":true,"soft":true,"handles":true,"label":"","app":"","sideL":true,"sideR":true,"slide":null,"base":null,"led":false,"opt":null}],""" +
            """"mats":{"carcass":"ldsp16w","front":"ldsp16k","back":"hdf3"},"created":0,"layout":"I","ws":"","free":null,"model":"","keep":false,""" +
            """"kx":{"joint":"butt","cutouts":true,"splash":600,"plinth":false,"cornice":false,"led":false,"ends":0,"endsUp":0},"type":"","pose":null,"baseH":null,"hand":"","handle":""}"""
        val f = json.decodeFromString(Furniture.serializer(), old)
        assertNull(f.look); assertNull(f.mats.frontUp); assertNull(f.mats.top); assertNull(f.mats.splash)
        assertEquals(old, json.encodeToString(Furniture.serializer(), f))
        // the workshop's older boards are saved as before (an issued quote's materials stay as they were)
        assertEquals("""{"id":"ldsp16w","kind":"board","name":"LDSP 16 · Oq","t":16,"l":2800,"w":2070,"price":"620000","grain":false,"rgb":"#F5F5F2","preset":true}""",
            json.encodeToString(Mat.serializer(), MAT_PRESETS.first { it.id == "ldsp16w" }))
        assertEquals(listOf("ldsp16w", "ldsp16k", "ldsp18a", "mdf18", "ldsp16mr", "hdf3", "wt38", "splash6", "band2", "band04"), MAT_PRESETS.take(10).map { it.id })
        assertTrue(MAT_PRESETS.take(10).all { it.finish.isEmpty() && it.tex == null && !it.byArea })
        // an order without a style saves as before
        val p = uz.metrx.app.data.Project("p", "A", industry = "furniture")
        assertFalse(json.encodeToString(uz.metrx.app.data.Project.serializer(), p).contains("fstyle"))
        // a new piece's look, upper fronts, worktop and backsplash are saved and read back
        val g = withPreset(f, "twotone")
        val out = json.encodeToString(Furniture.serializer(), g)
        assertTrue(out.contains("\"look\"") && out.contains("\"frontUp\":\"ag_white\""))
        assertEquals(g, json.decodeFromString(Furniture.serializer(), out))
    }

    @Test fun anOlderOrderCostsAndLooksAsBefore() {
        val k = kitchen().copy(kx = KExtras(splash = 600, plinth = true))
        assertNull(k.look)
        val c = cost(k)
        // the usual worktop and backsplash by the metre, the boards by the sheet, nothing of the design
        assertEquals("m", c.lines.single { it.key == "wt38" }.unit)
        assertEquals(splashMm(k) / 1000.0, c.lines.single { it.key == "splash6" }.qty, 1e-9)
        assertEquals("m", c.lines.single { it.key == "splash6" }.unit)
        assertTrue(c.lines.filter { it.group == "mat" && it.key in setOf("ldsp16w", "ldsp16k", "hdf3") }.all { it.unit == "sheet" })
        val design = setOf("gola", "frontShaker", "frontFluted", "legMetal", "ceilUnit", "fglass", "waterfall", "mirrorBronze", "mirrorGraphite",
            "ledSensor", "headSoft", "headTufted", "softPanel", "handle640", "handle1024")
        assertTrue(c.lines.none { it.key in design })
        assertTrue(lookHardware(k, ws).isEmpty())
        // the 3D gets the colours it had: flat, matte, no texture, grey handles
        val m = k.modules.first { !isUpper(it) && it.type == "base" }
        assertEquals(Surface("#CDBFAE", "matte", null, true, "ldsp16k", "flat"), lookOf(k, m, "front"))
        assertEquals("#4B4F58", lookOf(k, m, "worktop").rgb)
        assertEquals("#4B5563", lookOf(k, m, "handle").rgb)
        assertEquals("#E8E2D8", lookOf(k, null, "splash").rgb)
        // the same piece, its front changed to an older board, still costs by the sheet
        assertEquals("sheet", cost(k.copy(mats = k.mats.copy(front = "mdf18"))).lines.single { it.key == "mdf18" }.unit)
    }

    /* ---------------- the presets ---------------- */

    @Test fun exactlyTheSixApprovedPresets() {
        assertEquals(listOf("twotone", "gloss", "gola", "neo", "wood", "dark"), DESIGN_PRESETS.map { it.id })
        val ids = MAT_PRESETS.map { it.id }.toSet()
        DESIGN_PRESETS.forEach { p ->
            val g = withPreset(kitchen(), p.id)
            listOfNotNull(g.mats.front, g.mats.frontUp, g.mats.top, g.mats.splash, g.look!!.accent).forEach { assertTrue("${p.id} $it", it in ids) }
            assertEquals(p.id, presetOf(g))
            assertEquals(600, g.kx!!.splash)
            assertFalse(g.look!!.legs || g.look!!.fglass || g.look!!.waterfall)
        }
    }

    private data class Want(val front: String, val up: String?, val top: String, val splash: String, val handle: String, val hcol: String, val style: String,
                            val finish: String, val crown: String, val accent: String, val mirror: String, val fabric: String, val head: String)

    @Test fun eachPresetsFields() {
        val want = mapOf(
            "twotone" to Want("ag_graphite", "ag_white", "wt38m", "skGlass", "", "black", "flat", "gloss", "", "wd_walnut", "graphite", "olive", "vertical"),
            "gloss" to Want("ag_white", null, "wt38m", "skPrint", LONG_V, "chrome", "flat", "gloss", "", "wd_halifax", "silver", "grey", "panels"),
            "gola" to Want("sm_cashmere", null, "wt38c", "spTile", GOLA, "black", "flat", "matte", "", "wd_craft", "bronze", "mocha", "vertical"),
            "neo" to Want("en_ivory", null, "wt38o", "spTile", "handleKnob", "gold", "shaker", "matte", "cornice", "wd_walnut", "bronze", "cream", "tufted"),
            "wood" to Want("wd_halifax", "sm_white", "wt38m", "spTile", "", "black", "flat", "matte", "", "wd_halifax", "silver", "cream", "panels"),
            "dark" to Want("sm_black", "sm_graphite", "wt38d", "skGlass", LONG_V, "brass", "flat", "matte", "ceiling", "wd_walnut", "bronze", "navy", "vertical"))
        want.forEach { (id, w) ->
            val g = withPreset(kitchen(), id)
            val l = g.look!!
            assertEquals(id, w, Want(g.mats.front, g.mats.frontUp, g.mats.top!!, g.mats.splash!!, g.handle, l.hcol, l.style, l.finish, crownOf(g), l.accent, l.mirror, l.fabric, l.head))
        }
        // the cornice is the kitchen's extra; to the ceiling is the look's
        assertTrue(withPreset(kitchen(), "neo").kx!!.cornice)
        assertEquals("ceiling", withPreset(kitchen(), "dark").look!!.crown)
        assertFalse(withPreset(kitchen(), "dark").kx!!.cornice)
        // a two-tone kitchen's wall units take the upper board, in the cut list and in the 3D
        val t = withPreset(kitchen(), "twotone")
        val wall = t.modules.first { isUpper(it) }; val low = t.modules.first { it.type == "base" }
        assertEquals("ag_white", lookOf(t, wall, "front").mat); assertEquals("ag_graphite", lookOf(t, low, "front").mat)
        assertEquals("gloss", lookOf(t, wall, "front").finish)
        val rows = cutList(listOf(t), ws)
        assertTrue(rows.any { it.p.key == "fp.door" && it.mat == "ag_white" }); assertTrue(rows.any { it.p.key == "fp.door" && it.mat == "ag_graphite" })
        // neoclassic: enamel MDF, milled, the finish the look's; wood: a grained wood decor with its texture
        assertEquals(Surface("#EEE5D2", "matte", null, false, "en_ivory", "shaker"), lookOf(withPreset(kitchen(), "neo"), low, "front"))
        lookOf(withPreset(kitchen(), "wood"), low, "front").let { assertEquals("oak_light", it.tex); assertEquals("wood", it.finish); assertTrue(it.grain) }
        assertEquals("marble_white", lookOf(t, null, "worktop").tex)
        assertEquals("stone_dark", lookOf(withPreset(kitchen(), "dark"), null, "worktop").tex)
        assertEquals(HANDLE_RGB["brass"], lookOf(withPreset(kitchen(), "dark"), null, "handle").rgb)
    }

    @Test fun presetsOnOtherPieces() {
        // a kupe: the fronts, the tint; a new one gets the mirror on its middle door
        val kupe = newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws).copy(id = "s")
        assertEquals(3, kupe.modules[0].slide!!.n)
        val k = withPreset(kupe, "twotone", fresh = true)
        assertEquals("ag_graphite", k.mats.front); assertEquals("ag_white", k.mats.frontUp)
        assertEquals(listOf("ldsp", "mirror", "ldsp"), k.modules[0].slide!!.panels)
        assertEquals("mirror", middleFill(k)); assertEquals(MIRROR_RGB["graphite"], lookOf(k, null, "mirror").rgb)
        // not a kitchen: no worktop or backsplash, no crown; changing the style later leaves the doors
        assertNull(k.mats.top); assertNull(k.mats.splash); assertEquals("", k.look!!.crown)
        assertEquals(listOf("ldsp", "ldsp", "ldsp"), withPreset(k.copy(modules = k.modules.map { it.copy(slide = it.slide!!.copy(panels = listOf("ldsp", "ldsp", "ldsp"))) }), "gloss").modules[0].slide!!.panels)
        assertEquals("silver", withPreset(k, "gloss").look!!.mirror)
        // a hinged wardrobe with the Gola preset opens by push latches (Gola is a kitchen's)
        val ward = newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws).copy(id = "h")
        val gw = withPreset(ward, "gola")
        assertEquals("push", handleType(gw)); assertFalse(hasHandles(gw))
        assertEquals("gola", handleType(withPreset(kitchen(), "gola")))
        // a bed: fabric and headboard
        val bed = Furniture("b", "wardrobe", modules = listOf(Module("bm", "bed", 1700, 450, 2100, opt = Opt(bed = "legs", hb = 1100))), type = "bed")
        val gb = withPreset(bed, "neo")
        assertEquals("tufted", gb.look!!.head); assertEquals("cream", gb.look!!.fabric)
        assertEquals("boucle", lookOf(gb, null, "fabric").tex)
        assertEquals("velvet", lookOf(withPreset(bed, "dark"), null, "fabric").finish)
    }

    /* ---------------- boards and options ---------------- */

    @Test fun boardsFollowTheFinishAndTheStyle() {
        assertEquals("ag_white", boardFor("white", "gloss", "flat"))
        assertEquals("sm_white", boardFor("white", "matte", "flat"))
        assertEquals("en_white", boardFor("white", "gloss", "shaker"))
        assertEquals("en_olive", boardFor("olive", "matte", "fluted"))
        assertEquals("wd_walnut", boardFor("walnut", "gloss", "shaker"))
        assertEquals("navy", colourOf("sm_navy")); assertEquals("craft", colourOf("wd_craft")); assertNull(colourOf("ldsp16k")); assertNull(colourOf("ag_purple"))
        assertEquals("ag_cream", refinish("sm_cream", "gloss", "flat")); assertEquals("ldsp16k", refinish("ldsp16k", "gloss", "flat"))
        assertEquals("wt38o", worktopFor("stone", "onyx")); assertEquals("wt20d", worktopFor("slim", "dark")); assertEquals("wt38h", worktopFor("wood", "halifax"))
        assertEquals("slim", worktopKind("wt20m")); assertEquals("plain", worktopKind(null)); assertEquals("onyx", worktopDecor("wt38o"))
        assertEquals("skPrint", splashFor("print")); assertNull(splashFor("")); assertEquals("tile", splashKind("spTile"))
        // 27 colour fronts by the m², 6 woods, 8 worktops, 3 backsplashes; every one with a texture or none
        assertEquals(44, DECOR_PRESETS.size)
        assertTrue(DECOR_PRESETS.filter { it.kind == "board" }.all { it.byArea && it.finish.isNotEmpty() })
        assertTrue(DECOR_PRESETS.mapNotNull { it.tex }.all { it in TEX_IDS })
        assertEquals(MAT_PRESETS.size, MAT_PRESETS.map { it.id }.distinct().size)
        assertEquals(HW_PRESETS.size, HW_PRESETS.map { it.id }.distinct().size)
        // an enamel board shows the look's finish
        val k = kitchen().let { it.copy(mats = it.mats.copy(front = "en_white"), look = Look(finish = "gloss")) }
        assertEquals("gloss", lookOf(k, k.modules.first(), "front").finish)
    }

    @Test fun crownLegsWaterfallAndTheMiddleDoor() {
        val k = kitchen()
        assertEquals("cornice", crownOf(withCrown(k, "cornice"))); assertTrue(withCrown(k, "cornice").kx!!.cornice)
        assertEquals("ceiling", crownOf(withCrown(withCrown(k, "cornice"), "ceiling"))); assertFalse(withCrown(withCrown(k, "cornice"), "ceiling").kx!!.cornice)
        assertEquals("", crownOf(withCrown(withCrown(k, "ceiling"), "")))
        assertTrue(metalLegs(withLook(k) { it.copy(legs = true) })); assertEquals("", withLook(withPreset(k, "gola")) { it.copy(legs = true) }.look!!.preset)
        assertEquals(0, waterfallEnds(withLook(k) { it.copy(waterfall = true) }))
        val o = kitchen("O", island = 1800)
        assertEquals(2, waterfallEnds(withLook(o) { it.copy(waterfall = true) }))
        assertEquals(1, waterfallEnds(withLook(kitchen("P", island = 1600)) { it.copy(waterfall = true) }))
        val kupe = newFreeWardrobe("Kupe", "s2", 1800, 2500, 600, true, "slide", ws, n = 2)
        assertEquals(listOf("ldsp", "glass"), withMiddleFill(kupe, "glass").modules[0].slide!!.panels)
        assertEquals(setOf(1, 2), middleDoors(4))
    }

    /* ---------------- prices (Advanced) ---------------- */

    @Test fun decorBoardsAreBoughtByTheSquareMetre() {
        val k = kitchen().let { it.copy(mats = it.mats.copy(front = "ag_white")) }
        val l = line(k, "ag_white")!!
        assertEquals("m2", l.unit); assertEquals(BigInteger("400000"), l.price)
        val mm2 = cutList(listOf(k), ws).filter { it.mat == "ag_white" }.sumOf { it.p.L.toLong() * it.p.W * it.p.qty }
        assertEquals(Math.ceil(mm2 / 10000.0) / 100.0, l.qty, 1e-9)
        assertEquals(java.math.BigDecimal(400000).multiply(java.math.BigDecimal.valueOf(l.qty)).setScale(0, java.math.RoundingMode.HALF_UP).toBigInteger(), l.amount)
        // two-tone: each board its own line
        val t = withPreset(kitchen(), "twotone")
        assertEquals("m2", line(t, "ag_white")!!.unit); assertEquals("m2", line(t, "ag_graphite")!!.unit)
    }

    @Test fun worktopsAndBacksplashes() {
        val k = kitchen().copy(kx = KExtras(splash = 600))
        val run = worktopRuns(k).values.sum()
        listOf("wt38m" to "420000", "wt38c" to "400000", "wt20m" to "2150000").forEach { (id, p) ->
            val l = line(k.copy(mats = k.mats.copy(top = id)), id)!!
            assertEquals("m", l.unit); assertEquals(run / 1000.0, l.qty, 1e-9); assertEquals(BigInteger(p), l.price)
            assertNull(line(k.copy(mats = k.mats.copy(top = id)), "wt38"))
        }
        // skinali, printed skinali and tile by the area: the backsplash's length × its height
        listOf("skGlass" to "380000", "skPrint" to "480000", "spTile" to "230000").forEach { (id, p) ->
            val l = line(k.copy(mats = k.mats.copy(splash = id)), id)!!
            assertEquals("m2", l.unit); assertEquals(Math.ceil(splashMm(k) * 600 / 10000.0) / 100.0, l.qty, 1e-9); assertEquals(BigInteger(p), l.price)
            assertNull(line(k.copy(mats = k.mats.copy(splash = id)), "splash6"))
        }
        // two kitchens with different worktops: a line each
        val two = costOf(listOf(k.copy(id = "a", mats = k.mats.copy(top = "wt38m")), k.copy(id = "b")), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(setOf("wt38m", "wt38"), two.lines.filter { it.group == "mat" && it.key.startsWith("wt") }.map { it.key }.toSet())
    }

    @Test fun golaLongHandlesAndKnobs() {
        val u = units()
        val usual = hardware(listOf(u), ws)["handle"]!!
        // Gola: the base and tall units' handles become the profile, the wall unit's a push latch
        val g = withHandleType(u, "gola")
        val hw = hardware(listOf(g), ws)
        assertNull(hw["handle"])
        val drawers = u.modules.first { it.id == "d" }.fronts.n
        assertEquals(600 * 1 + 600 * drawers + 600 * 2, hw["gola"])
        assertEquals((hardware(listOf(u), ws)["push"] ?: 0) + u.modules.first { it.id == "w" }.fronts.n, hw["push"])
        assertEquals(BigInteger("150000") * BigInteger.valueOf(Math.ceil(hw["gola"]!! / 1000.0).toLong()), line(g, "gola")!!.amount)
        assertEquals("m", line(g, "gola")!!.unit)
        // long verticals: 1024 on the pantry's tall doors, 640 on the 717 mm doors, 320 on the drawers
        val lv = withHandleType(u, "long")
        assertEquals(LONG_V, lv.handle)
        val ids = longHandleIds(lv, ws)
        assertEquals(usual, ids.size)
        val tallDoors = u.modules.first { it.id == "t" }.fronts.n
        assertEquals(tallDoors, ids.count { it == "handle1024" })
        assertEquals(2 + u.modules.first { it.id == "w" }.fronts.n, ids.count { it == "handle640" })
        assertEquals(drawers, ids.count { it == "handleLong" })
        val c = cost(lv)
        assertEquals(tallDoors.toDouble(), c.lines.single { it.key == "handle1024" }.qty, 0.0)
        assertEquals(BigInteger("85000") * BigInteger.valueOf(ids.count { it == "handle640" }.toLong()), c.lines.single { it.key == "handle640" }.amount)
        assertNull(c.lines.singleOrNull { it.key == "handle" })
        // knobs at the knob's price (Change for all, as before)
        assertEquals(usual.toDouble(), cost(withHandleType(u, "knob")).lines.single { it.key == "handleKnob" }.qty, 0.0)
        // push: no handles at all
        assertNull(hardware(listOf(withHandleType(u, "push")), ws)["handle"])
    }

    @Test fun frontStylesLegsCeilingAndWaterfall() {
        val k = kitchen()
        val doorsMm2 = k.modules.sumOf { m -> partsOf(m, ws).filter { it.role == "front" && it.key in setOf("fp.door", "fp.dFace", "fp.panel") }.sumOf { it.L.toLong() * it.W * it.qty } }
        val sh = line(withLook(k) { it.copy(style = "shaker") }, "frontShaker")!!
        assertEquals("m2", sh.unit); assertEquals(Math.ceil(doorsMm2 / 10000.0) / 100.0, sh.qty, 1e-9); assertEquals(BigInteger("100000"), sh.price)
        assertEquals(BigInteger("250000"), line(withLook(k) { it.copy(style = "fluted") }, "frontFluted")!!.price)
        assertNull(line(withLook(k) { it.copy(style = "fluted") }, "frontShaker"))
        // metal legs: the legs priced as metal ones, no plinth
        val withPlinth = k.copy(kx = (k.kx ?: KExtras()).copy(plinth = true))
        val legs = hardware(listOf(withPlinth), ws)["leg"]!!
        val ml = withLook(withPlinth) { it.copy(legs = true) }
        assertEquals(legs.toDouble(), line(ml, "legMetal")!!.qty, 0.0); assertEquals(BigInteger("45000") * BigInteger.valueOf(legs.toLong()), line(ml, "legMetal")!!.amount)
        assertNull(line(ml, "leg")); assertNull(line(ml, "plinthK")); assertTrue(line(withPlinth, "plinthK") != null)
        // a row of units to the ceiling by the metre of the wall units; the cornice and LED as before
        val ceil = line(withCrown(k, "ceiling"), "ceilUnit")!!
        assertEquals(Math.ceil(wallUnitsMm(k) / 1000.0 - 1e-9), ceil.qty, 0.0); assertEquals(BigInteger("800000"), ceil.price)
        assertTrue(line(withCrown(k, "cornice"), "cornice") != null)
        val led = k.copy(kx = (k.kx ?: KExtras()).copy(led = true))
        assertTrue(line(led, "led") != null && line(led, "ledPsu") != null)
        // the waterfall ends of an island
        val o = withLook(kitchen("O", island = 1800)) { it.copy(waterfall = true) }
        assertEquals(2.0, line(o, "waterfall")!!.qty, 0.0); assertEquals(BigInteger("2400000"), line(o, "waterfall")!!.amount)
    }

    @Test fun mirrorsGlassLedAndBeds() {
        // a kupe's mirror door in bronze; lacobel stays the glass item
        val kupe = withMiddleFill(newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws).copy(id = "s"), "mirror")
        val mirror = hardware(listOf(kupe), ws)["mirror"]!!
        val br = withLook(kupe) { it.copy(mirror = "bronze") }
        assertEquals(mirror, hardware(listOf(br), ws)["mirrorBronze"]); assertNull(hardware(listOf(br), ws)["mirror"])
        assertEquals(BigInteger("350000"), line(br, "mirrorBronze")!!.price)
        assertTrue(line(withLook(kupe) { it.copy(mirror = "graphite") }, "mirrorGraphite") != null)
        assertTrue(line(withMiddleFill(kupe, "glass"), "glass") != null)
        // the inside LED with a door sensor a sliding door
        val lit = withLook(kupe) { it.copy(led = true) }
        val hw = hardware(listOf(lit), ws)
        assertEquals(kupe.modules[0].w - 2 * ws.t, hw["led"]); assertEquals(1, hw["ledPsu"]); assertEquals(3, hw["ledSensor"])
        assertEquals(BigInteger("180000"), line(lit, "ledSensor")!!.amount)
        // fluted glass over a vitrina's glass doors
        val vit = Furniture("v", "wardrobe", modules = listOf(Module("vm", "wardrobe", 900, 2000, 400, sections = listOf(Section(900, Fronts("door", 2), face = "glass")))))
        val glass = hardware(listOf(vit), ws)["glassDoor"]!!
        val fg = withLook(vit) { it.copy(fglass = true) }
        assertEquals(glass, hardware(listOf(fg), ws)["fglass"]); assertEquals("fluted_glass", lookOf(fg, null, "glass").tex)
        assertEquals(BigInteger("450000"), line(fg, "fglass")!!.price)
        // a bed's upholstered headboard above the frame, tufted dearer, and the soft wall panel
        val bed = Furniture("b", "wardrobe", modules = listOf(Module("bm", "bed", 1700, 450, 2100, opt = Opt(bed = "legs", hb = 1100))), type = "bed")
        val soft = withLook(bed) { it.copy(head = "vertical") }
        assertEquals(1700 * (1100 - 450), hardware(listOf(soft), ws)["headSoft"])
        assertEquals(1.11, line(soft, "headSoft")!!.qty, 1e-9); assertEquals(BigInteger("999000"), line(soft, "headSoft")!!.amount)
        assertEquals(BigInteger("1300000"), line(withLook(bed) { it.copy(head = "tufted") }, "headTufted")!!.price)
        assertNull(line(withLook(bed) { it.copy(head = "tufted") }, "headSoft"))
        val pan = line(withLook(bed) { it.copy(panel = true) }, "softPanel")!!
        assertEquals(Math.ceil((1700 + 800) * 1300 / 10000.0) / 100.0, pan.qty, 1e-9)
        assertNull(line(bed, "headSoft")); assertNull(line(bed, "softPanel"))
    }

    @Test fun theQuoteNamesTheNewMaterialsAndHandles() {
        val p = uz.metrx.app.data.Project("p", "A", industry = "furniture", furniture = listOf(withPreset(kitchen(), "gola")))
        val sn = uz.metrx.app.report.furnSnap(uz.metrx.app.report.snapshotOf(p, uz.metrx.app.geo.LenUnit.M, "", "", uz.metrx.app.data.PdfParts()), p, ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(setOf("ldsp16w", "sm_cashmere", "hdf3", "wt38c", "spTile"), sn.fmats.map { it.id }.toSet())
        assertEquals("Gola profili (metr)", sn.fhandles)
        // an older order: the usual materials and handle, as before
        val old = uz.metrx.app.data.Project("q", "B", industry = "furniture", furniture = listOf(kitchen().copy(kx = KExtras(splash = 600))))
        val so = uz.metrx.app.report.furnSnap(uz.metrx.app.report.snapshotOf(old, uz.metrx.app.geo.LenUnit.M, "", "", uz.metrx.app.data.PdfParts()), old, ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(listOf("ldsp16w", "ldsp16k", "hdf3", "wt38", "splash6"), so.fmats.map { it.id })
        assertEquals("Tutqich skoba 128", so.fhandles)
    }
}
