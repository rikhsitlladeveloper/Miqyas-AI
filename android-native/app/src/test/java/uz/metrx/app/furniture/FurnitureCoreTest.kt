package uz.metrx.app.furniture

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger

/** The shared furniture core (furniture plan section 6) against furniture-cases.json, which the iPhone app uses too. */
class FurnitureCoreTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val ws = Workshop()
    private val cases: List<JsonObject> by lazy {
        val text = javaClass.classLoader!!.getResource("furniture-cases.json")!!.readText()
        json.parseToJsonElement(text).jsonObject["cases"]!!.jsonArray.map { it.jsonObject }
    }

    private data class P(val key: String, val L: Int, val W: Int, val bands: List<Int>)

    @Test fun partsMatchTheCases() {
        assertEquals(4, cases.size)
        cases.forEach { c ->
            val m = json.decodeFromJsonElement(Module.serializer(), c["module"]!!)
            val want = c["parts"]!!.jsonArray.associate { e ->
                val a = e.jsonArray
                P(a[0].jsonPrimitive.content, a[1].jsonPrimitive.int, a[2].jsonPrimitive.int, a[4].jsonArray.map { it.jsonPrimitive.int }) to a[3].jsonPrimitive.int
            }
            val got = HashMap<P, Int>()
            partsOf(m, ws).forEach { p -> val k = P(p.key, p.L, p.W, listOf(p.bands.l1, p.bands.l2, p.bands.s1, p.bands.s2)); got[k] = (got[k] ?: 0) + p.qty }
            assertEquals(c["name"]!!.jsonPrimitive.content, want, got)
        }
    }

    @Test fun hardwareMatchesTheCases() {
        cases.forEach { c ->
            val m = json.decodeFromJsonElement(Module.serializer(), c["module"]!!)
            val want = c["hardware"]!!.jsonObject.mapValues { it.value.jsonPrimitive.int }
            assertEquals(c["name"]!!.jsonPrimitive.content, want, hardwareOf(m, ws))
        }
    }

    @Test fun cutSizesLeaveRoomForTheBanding() {
        val m = json.decodeFromJsonElement(Module.serializer(), cases[0]["module"]!!)
        val rows = cutList(listOf(Furniture("f", "kitchen", modules = listOf(m))), ws)
        val door = rows.single { it.p.key == "fp.door" }
        assertEquals(713 to 293, door.cutL to door.cutW)          // 2 mm thick banding all round
        val side = rows.single { it.p.key == "fp.side" }
        assertEquals(704 to 558, side.cutL to side.cutW)          // banded on its front edge only
        assertEquals("ldsp16k", door.mat); assertEquals("ldsp16w", side.mat)
    }

    @Test fun bandingIsCountedWithTrimming() {
        val m = Module("w", "wall", 600, 720, 300, fronts = Fronts("open", 0))
        val rows = cutList(listOf(Furniture("f", "kitchen", modules = listOf(m))), ws)
        // sides 2 × (720 + 30), top and bottom 2 × (568 + 30): thick only
        val (thick, thin) = bandMetres(rows)
        assertEquals(2.696, thick, 1e-9); assertEquals(0.0, thin, 1e-9)
    }

    @Test fun sheetLayoutPacksAndKeepsCutsApart() {
        val rows = listOf(CutRow(FPart("x", "", "carcass", 1000, 1000, 5), "m", 1000, 1000))
        val l = layout(rows, "m", 2800, 2070, 4, 10)
        // 2 across (1000 + 4 + 1000 ≤ 2780) and 2 strips (≤ 2050) a sheet: 5 pieces → 2 sheets
        assertEquals(2, l.sheets.size); assertEquals(4, l.sheets[0].placed.size)
        l.sheets.forEach { s ->
            s.placed.forEach { a ->
                assertTrue(a.x >= 0 && a.y >= 0 && a.x + a.w <= 2780 && a.y + a.h <= 2050)
                s.placed.filter { it !== a }.forEach { b ->
                    val apart = a.x + a.w + 4 <= b.x || b.x + b.w + 4 <= a.x || a.y + a.h + 4 <= b.y || b.y + b.h + 4 <= a.y
                    assertTrue("pieces closer than the saw cut", apart)
                }
            }
        }
    }

    @Test fun grainNeverTurnsAndTooLongIsReported() {
        val rows = listOf(
            CutRow(FPart("door", "", "front", 2500, 400, 1, grain = true), "k", 2500, 400),
            CutRow(FPart("tall", "", "front", 2400, 400, 1, grain = true), "k", 300, 2400)   // its grain runs across 2400: no sheet can take it
        )
        val l = layout(rows, "k", 2800, 2070, 4, 10)
        assertEquals(listOf(1), l.unplaced)
        assertEquals(2500, l.sheets.single().placed.single().w)
    }

    @Test fun orderCostAddsUp() {
        val ms = cases.take(3).map { json.decodeFromJsonElement(Module.serializer(), it["module"]!!) }
        val c = costOf(listOf(Furniture("f", "kitchen", modules = ms)), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(c.total, c.sum("mat") + c.sum("hw") + c.sum("lab"))
        assertEquals(0, c.missing)
        // every material needs at least its parts' area in sheets, and the packing wastes at most one more sheet here
        c.layouts.forEach { l ->
            val area = c.rows.filter { it.mat == l.mat }.sumOf { it.cutL.toLong() * it.cutW * it.p.qty }
            val least = Math.ceil(area / (2780.0 * 2050)).toInt()
            assertTrue("${l.mat}: ${l.sheets.size} sheets for ${area / 1e6} m²", l.sheets.size in least..least + 1)
        }
        assertEquals(1, c.layouts.single { it.mat == "ldsp16k" }.sheets.size)
        assertTrue(c.layouts.all { it.unplaced.isEmpty() })
        // labour: every sheet cut, 3 modules, installation and delivery
        val sheets = c.layouts.sumOf { it.sheets.size }.toLong()
        assertEquals(BigInteger.valueOf(sheets * 45000L + 3 * 120000L + 1500000 + 300000), c.lines.filter { it.group == "lab" && it.key != "fc.band" }.fold(BigInteger.ZERO) { a, x -> a + x.amount })
    }

    @Test fun marginRoundsHalfUp() {
        assertEquals(BigInteger.valueOf(32067100), withMargin(BigInteger.valueOf(24667000), 30))
        assertEquals(BigInteger.valueOf(13), withMargin(BigInteger.valueOf(10), 25))   // 12,5 → 13
    }

    @Test fun runnersAndHinges() {
        assertEquals(550, runnerLen(560)); assertEquals(300, runnerLen(280)); assertEquals(600, runnerLen(700))
        assertEquals(listOf(2, 3, 4, 5), listOf(717, 1500, 2000, 2497).map { hingesFor(it) })
    }

    @Suppress("unused") private fun JsonArray.ints() = map { it.jsonPrimitive.int }
}
