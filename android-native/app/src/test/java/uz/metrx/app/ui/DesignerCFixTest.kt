package uz.metrx.app.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.END_ID
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.SK
import uz.metrx.app.furniture.Slot
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.absorberSide
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.deleteToGap
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.gapLeft
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.maxW
import uz.metrx.app.furniture.onFreeWalls
import uz.metrx.app.furniture.resize
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.ui.furniture.bubbleLeft
import uz.metrx.app.ui.furniture.isBodyKey
import uz.metrx.app.ui.furniture.labelSize
import uz.metrx.app.ui.furniture.nextTeachStep
import uz.metrx.app.ui.furniture.parsePick
import uz.metrx.app.ui.furniture.pickRay
import uz.metrx.app.ui.furniture.pogM
import uz.metrx.app.ui.three.Cam3D
import java.io.File

/** The emulator check's Designer C v2 bugs (27 Oct 2026): 3D taps, placeholders, the right edge, labels, the hint. */
class DesignerCFixTest {
    private val ws = Workshop()
    private fun mod(id: String, w: Int) = Slot(id, w, SK.MOD)
    private fun fixed(id: String, w: Int) = Slot(id, w, SK.FIXED, listOf(450, 600))
    private fun gap(id: String, w: Int) = Slot(id, w, SK.GAP, min = 0)
    private fun fill(id: String, w: Int) = Slot(id, w, SK.FILLER, min = 10)
    private fun end(w: Int) = Slot(END_ID, w, SK.END, min = 0)

    /* ---------------- the right edge (bug 3) ---------------- */

    @Test fun theRightEdgeTakesFromTheRight() {
        // a filler on each side: the old rule took the left one (nearest), growing the module to the left
        val row = listOf(fill("fl", 250), mod("a", 600), mod("b", 600), fill("fr", 100), end(0))
        val r = resize(row, 1, 650, side = 1)
        assertTrue(r.ok); assertEquals("fr", r.aid); assertFalse(r.back)
        assertEquals(listOf(250, 650, 600, 50), r.row.filter { it.kind != SK.END }.map { it.w })
        // the left filler is untouched: the module's left edge stays where it was
        assertEquals(250, r.row.first().w)
    }

    @Test fun withNoSpaceOnTheRightTheNeighbourThereGives() {
        val row = listOf(gap("g", 300), mod("a", 600), mod("b", 600))
        val r = resize(row, 1, 700, side = 1)
        assertEquals("b", r.aid); assertFalse(r.back)
        assertEquals(listOf(300, 700, 500), r.row.map { it.w })
        assertEquals(1050, maxW(row, 1, side = 1))
    }

    @Test fun onlyWhenNothingOnTheRightCanGiveTheLeftDoes() {
        // the dishwasher keeps its width and the free end is 0: the left filler gives, and says so
        val row = listOf(fill("fl", 250), mod("a", 600), fixed("dw", 600), end(0))
        val s = absorberSide(row, 1, 1)
        assertEquals(0, s.i); assertTrue(s.back)
        val r = resize(row, 1, 800, side = 1)
        assertTrue(r.ok); assertEquals("fl", r.aid); assertTrue(r.back); assertEquals(50, r.aw1)
    }

    @Test fun shrinkingByTheRightEdgeGivesTheRoomToTheRight() {
        val row = listOf(fill("fl", 50), mod("a", 600), mod("b", 600), end(0))
        val r = resize(row, 1, 450, side = 1)
        assertTrue(r.ok); assertEquals(END_ID, r.aid); assertEquals(150, r.aw1)
        assertEquals(50, r.row.first().w)
    }

    @Test fun typedWidthsKeepTheNearestRule() {
        val row = listOf(fill("fl", 250), mod("a", 600), mod("b", 600), fill("fr", 100), end(0))
        assertEquals("fl", resize(row, 1, 650).aid)
    }

    /* ---------------- the delete toast (bug 2) ---------------- */

    @Test fun theGapLeftByADeleteIsItsMergedWidth() {
        val row = listOf(mod("a", 600), mod("b", 600), gap("g", 300), mod("c", 600))
        // b deleted: its 600 and the 300 beside it are one gap of 900
        val out = deleteToGap(row, 1)
        assertEquals(900, gapLeft(out, "b", 1, 600))
        // a gap before it: merged into that one
        val row2 = listOf(gap("g", 200), mod("a", 600), mod("b", 600))
        val out2 = deleteToGap(row2, 1)
        assertEquals(800, gapLeft(out2, "a", 1, 600))
        // alone
        assertEquals(600, gapLeft(deleteToGap(listOf(mod("a", 600), mod("b", 600)), 0), "a", 0, 600))
    }

    /** Every dzc.* text with {…} gets each of its values where it is used (the toast showed "{v} mm qoldi"). */
    @Test fun everyDesignerPlaceholderIsFilled() {
        val root = listOf(File("src/main"), File("app/src/main")).first { File(it, "assets/strings.json").exists() }
        val all = kotlinx.serialization.json.Json.parseToJsonElement(File(root, "assets/strings.json").readText()) as kotlinx.serialization.json.JsonObject
        val srcs = File(root, "java").walkTopDown().filter { it.isFile && it.name.endsWith(".kt") }.map { it.name to it.readText() }.toList()
        val ph = Regex("""\{(\w+)\}""")
        val bad = ArrayList<String>()
        var checked = 0
        all.forEach { (k, v) ->
            if (!k.startsWith("dzc.")) return@forEach
            val names = (v as kotlinx.serialization.json.JsonArray).flatMap { e -> ph.findAll(e.toString()).map { it.groupValues[1] }.toList() }.toSet()
            if (names.isEmpty()) return@forEach
            srcs.forEach { (file, s) ->
                var at = s.indexOf("\"$k\"")
                while (at >= 0) {
                    val ls = s.lastIndexOf('\n', at) + 1
                    var le = at
                    repeat(3) { le = s.indexOf('\n', le + 1).let { if (it < 0) s.length else it } }
                    val call = s.substring(ls, le)
                    val miss = names.filter { n -> !Regex("\"$n\"\\s+to\\b").containsMatchIn(call) }
                    if (miss.isNotEmpty()) bad += "$k in $file: $miss"
                    checked++
                    at = s.indexOf("\"$k\"", at + 1)
                }
            }
        }
        assertTrue("checked $checked", checked > 50)
        assertTrue(bad.joinToString("\n"), bad.isEmpty())
    }

    @Test fun theNewTextsAreInFourLanguages() {
        val root = listOf(File("src/main"), File("app/src/main")).first { File(it, "assets/strings.json").exists() }
        val all = kotlinx.serialization.json.Json.parseToJsonElement(File(root, "assets/strings.json").readText()) as kotlinx.serialization.json.JsonObject
        listOf("dzc.fromLeft", "dzc.closed0", "dzc.took", "dzc.teachI1", "dzc.teachI2").forEach { k ->
            val v = all[k] as kotlinx.serialization.json.JsonArray
            assertEquals(k, 4, v.size)
            v.forEach { assertTrue(k, it.toString().length > 3) }
            // the Uzbek apostrophe is ‘ (U+2018), never the ASCII one
            assertFalse(k, v[0].toString().contains('\''))
        }
    }

    /* ---------------- 3D taps (bug 1) ---------------- */

    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val shell = buildShell(listOf(room), true)
    private val kitchen = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L").let { f0 ->
        autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList())
    }

    @Test fun aTapOnACarcassPicksItsModuleAndNothingBehindIt() {
        val fur = furniture3D(listOf(kitchen), shell.bases, ws, { 0xCDBFAE }, emptySet(), split = true)
        val a = shell.bases.getValue("A")
        val low = kitchen.modules.filter { it.wall == "A" && !isUpper(it) && it.type == "base" }.sortedBy { it.x }
        assertTrue(low.size >= 2)
        // every module has its body to tap
        low.forEach { m -> assertTrue(m.id, fur.bodies.any { it.key == "${m.id}:body" }) }
        // from above the worktop straight down onto a base unit, in front of the wall units: no front there, its body
        val m = low[1]
        val top = a.at((m.x + m.w / 2.0) / 1000, 2.5, .5)
        val k = fur.pickRay(top, V3(0.0, -1.0, 0.0))
        assertEquals("${m.id}:body", k)
        assertEquals(m.id, parsePick(k!!).mid); assertNull(parsePick(k).front)
        // nearer the wall the wall unit over it is in the way, and it is what is picked
        val over = fur.pickRay(a.at((m.x + m.w / 2.0) / 1000, 2.6, .15), V3(0.0, -1.0, 0.0))
        assertTrue(over != null && kitchen.modules.first { it.id == parsePick(over).mid }.let { isUpper(it) })
        // along the wall through the whole row at the units' middle height, from past its start: the first unit, not
        // a front further along that the ray would reach through the carcasses
        val first = kitchen.modules.filter { it.wall == "A" && !isUpper(it) && it.type != "gap" }.minBy { it.x }
        val side = a.at(-1.0, .4, .3)
        val hit = fur.pickRay(side, a.dir(1.0, 0.0).unit())
        assertNotNull(hit); assertEquals(first.id, parsePick(hit!!).mid)
    }

    @Test fun aTapOnAFrontStillPicksTheFront() {
        val fur = furniture3D(listOf(kitchen), shell.bases, ws, { 0xCDBFAE }, emptySet(), split = true)
        val a = shell.bases.getValue("A")
        val m = kitchen.modules.first { it.wall == "A" && it.type == "base" && it.fronts.kind == "door" }
        // from the room, straight at the module's front at half its height
        val eye = a.at((m.x + m.w / 4.0) / 1000, (m.elev + 100 + m.h / 2.0) / 1000, 2.0)
        val k = fur.pickRay(eye, a.dir(0.0, -1.0).unit())
        assertNotNull(k); assertFalse(k, isBodyKey(k!!))
        assertEquals(m.id, parsePick(k).mid); assertNotNull(parsePick(k).front)
    }

    @Test fun aWardrobeSectionsBodyNamesItsSection() {
        assertEquals(2, parsePick("w1:s2:body").sec)
        assertNull(parsePick("w1:s2:body").front)
        assertTrue(isBodyKey("w1:body")); assertFalse(isBodyKey("w1:s0:f1"))
    }

    /** The tap's ray and the picture's projection are one camera: a point projected and cast back lies on the ray. */
    @Test fun theTapRayGoesThroughWhatIsDrawnThere() {
        val cam = Cam3D()
        cam.resize(1080, 1500)
        cam.tgt = V3(1.5, .6, 1.2); cam.r = 7.0
        listOf(.95 to 2.3, .07 to Math.PI / 2, .6 to .4).forEach { (phi, theta) ->
            cam.phi = phi; cam.theta = theta
            listOf(V3(.3, .8, .2), V3(2.8, .1, 2.1), V3(1.5, 2.0, .5)).forEach { p ->
                val o = cam.project(p) ?: return@forEach
                val (e, d) = cam.ray(o.x, o.y)
                val t = (p - e).dot(d)
                val off = (e + d * t - p).len()
                assertTrue("off $off at phi $phi", off < 1e-3)
            }
        }
    }

    /* ---------------- labels and bubbles (bugs 4, 7) ---------------- */

    @Test fun aBubbleNearTheEdgeSlidesIn() {
        // 300 px wide, centred at 40 px on a 1080 px canvas: it starts at the padding, not at −110
        assertEquals(16, bubbleLeft(40f, 300, 1080, 16))
        assertEquals(1080 - 300 - 16, bubbleLeft(1070f, 300, 1080, 16))
        assertEquals(390, bubbleLeft(540f, 300, 1080, 16))
        // wider than the canvas: centred
        assertEquals(0, bubbleLeft(540f, 1200, 1080, 16))
    }

    @Test fun aToolLabelShrinksRatherThanBreakAWord() {
        // a word "fits" at .63 of its size a letter in 60: "Qo‘shimcha" (10 letters) only from 9.5 sp down
        val fits = { w: String, sp: Float -> w.length * sp * .63f <= 60f }
        assertEquals(9.5f, labelSize("Qo‘shimcha", 11.5f, 9f, .5f, fits))
        assertEquals(11.5f, labelSize("Turi", 11.5f, 9f, .5f, fits))
        // two words: each on its own line, the longer one ("ko‘rish", 7) decides
        assertEquals(11f, labelSize("Ichini ko‘rish", 11.5f, 9f, .5f) { w, sp -> w.length * sp <= 80f })
        // nothing fits: the smallest
        assertEquals(9f, labelSize("Uzuuuuuuuuuuuuuuuun", 11.5f, 9f, .5f, fits))
    }

    /* ---------------- the hint (bug 6) ---------------- */

    @Test fun theHintPlaysItsThreeStepsThenEnds() {
        assertEquals(1, nextTeachStep(0)); assertEquals(2, nextTeachStep(1)); assertNull(nextTeachStep(2))
        assertTrue(uz.metrx.app.ui.furniture.TEACH_STEP_MS in 2500..3500)
    }

    /* ---------------- the order's numbers (bug 10) ---------------- */

    @Test fun runningMetresAreRoundedOneWay() {
        assertEquals("5,0", pogM(4970, false)); assertEquals("5,4", pogM(5400, false)); assertEquals("5.4", pogM(5449, true))
        assertEquals("0,0", pogM(-20, false))
    }

    @Test fun aPieceInADrawnRoomIsPicturedOnTheMadeUpWalls() {
        // a kitchen on a drawn room's walls E and F: the card's made-up room has A–D only, so nothing was drawn
        val f = kitchen.copy(walls = listOf("E", "F"), roomId = "r9", modules = kitchen.modules.map { it.copy(wall = if (it.wall == "A") "E" else "F") })
        val g = onFreeWalls(f)
        assertEquals(listOf("A", "B"), g.walls)
        assertTrue(g.modules.all { it.wall == "A" || it.wall == "B" })
        assertEquals(f.modules.count { it.wall == "E" }, g.modules.count { it.wall == "A" })
        val b = buildShell(listOf(freeRoom(g)), true, true)
        val fur = furniture3D(listOf(g), b.bases, ws, { 0xCDBFAE }, emptySet())
        assertTrue(fur.parts.isNotEmpty())
        // a piece already on them is left as it is
        assertTrue(onFreeWalls(kitchen) === kitchen)
    }
}
