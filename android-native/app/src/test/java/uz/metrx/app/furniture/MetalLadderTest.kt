package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.math.BigInteger

/**
 * A bunk's or loft bed's metal ladder ([Look.legs]; the 3D's round tubes): bought as one "ladderMetal" (650 000 a bed),
 * its board stringers and rungs off the parts list, the cut list and the labels; its guards stay boards in the wood
 * accent (iPhone MetalLadderTests, the same cases and numbers).
 */
class MetalLadderTest {
    private val ws = Workshop()

    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }
    private fun piece(id: String) = pieceOf(fModel(id)!!, emptyMap(), ws, id)

    @Test fun aMetalLadderIsBoughtNotCut() {
        listOf("bunk", "loft").forEach { id ->
            val f = piece(id)
            val wood = withLook(f) { it.copy(accent = "wd_walnut", legs = false) }
            val metal = withLook(f) { it.copy(accent = "wd_walnut", legs = true) }
            val m = metal.modules.first { it.type == id }
            assertTrue(id, metalLadder(metal, m)); assertFalse(id, metalLadder(wood, m))
            // the box itself still has its board ladder (the 3D draws the tubes where those boards are)
            assertEquals(id, 2, partsOf(m, ws).filter { it.key == "fp.ladder" }.sumOf { it.qty })
            assertTrue(id, partsOf(m, ws).any { it.key == "fp.rung" })
            // in wood: the stringers, the rungs and the guards are cut, from the accent
            val wk = partsWithMat(wood, ws).map { it.first.key }
            assertTrue(id, wk.containsAll(listOf("fp.ladder", "fp.rung", "fp.guard")))
            // in metal: no stringers and rungs in the parts list, the cut list or the labels
            assertTrue(id, partsWithMat(metal, ws).none { it.first.key in LADDER_KEYS })
            assertTrue(id, cutList(listOf(metal), ws).none { it.p.key in LADDER_KEYS })
            assertTrue(id, labelsOf(listOf(metal), ws).none { it.key in LADDER_KEYS })
            // the guards stay boards in the accent, everything else as it was
            assertEquals(id, setOf("wd_walnut"), partsWithMat(metal, ws).filter { it.first.key == "fp.guard" }.map { it.second }.toSet())
            assertEquals(id, partsWithMat(wood, ws).filterNot { it.first.key in LADDER_KEYS }, partsWithMat(metal, ws))
            // the hardware: one metal ladder a bed, 650 000
            assertNull(id, hardware(listOf(wood), ws)["ladderMetal"])
            assertEquals(id, 1, hardware(listOf(metal), ws)["ladderMetal"])
            val l = line(metal, "ladderMetal")!!
            assertEquals(id, 1.0, l.qty, 1e-9); assertEquals(id, BigInteger("650000"), l.amount)
            assertNull(id, line(wood, "ladderMetal"))
            // less walnut to buy: only the guards
            assertTrue(id, line(metal, "wd_walnut")!!.qty < line(wood, "wd_walnut")!!.qty)
            // two beds, two ladders
            assertEquals(id, 2, hardware(listOf(metal, metal.copy(id = "b2")), ws)["ladderMetal"])
        }
    }

    @Test fun noMetalLadderWithoutTheLooksMetalOrOnOtherBeds() {
        // a bunk with no look at all keeps its board ladder
        val bare = piece("bunk").copy(look = null)
        assertTrue(partsWithMat(bare, ws).any { it.first.key == "fp.ladder" })
        assertNull(hardware(listOf(bare), ws)["ladderMetal"])
        // a bed on metal legs: its legs, no ladder
        val bed = withLook(piece("bed")) { it.copy(legs = true) }
        assertFalse(metalLadder(bed, bed.modules[0]))
        assertNull(hardware(listOf(bed), ws)["ladderMetal"])
    }

    @Test fun theMetalLadderIsAWorkshopItem() {
        assertTrue(HW_PRESETS.any { it.id == "ladderMetal" && it.kind == "ladderMetal" && it.name == "Metall narvon" && it.price == "650000" && it.preset })
        assertEquals("pcs", hwUnit("ladderMetal"))
        val file = listOf(File("src/main/assets/strings.json"), File("app/src/main/assets/strings.json")).first { it.exists() }
        val all = kotlinx.serialization.json.Json.parseToJsonElement(file.readText()) as kotlinx.serialization.json.JsonObject
        listOf("hp.ladderMetal", "hk.ladderMetal").forEach { k ->
            val v = all[k] as kotlinx.serialization.json.JsonArray
            assertEquals(k, 4, v.size)
            assertTrue(k, v.all { it.toString().trim('"').isNotBlank() })
        }
        assertEquals("\"Metall narvon\"", (all["hp.ladderMetal"] as kotlinx.serialization.json.JsonArray)[0].toString())
    }
}
