package uz.metrx.app.furniture

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.geo.vitrinaDishes
import uz.metrx.app.geo.vitrinaShelves
import java.math.BigInteger

/**
 * A kitchen's glass-door wall unit, the vitrina (Kitchen.kt glassDoors; the approved mockup's lit wall unit with
 * dishes): its glass doors bought by the m², not cut; the fluted glass only when the look has it; hinges and handles
 * as any door's, push latches when the handle type says so; an older kitchen saved as it was (iPhone
 * KitchenVitrinaTests, the same cases and numbers).
 */
class KitchenVitrinaTest {
    private val ws = Workshop()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun vitrina(w: Int = 600) = template("vitrina", ws, "A", w).copy(id = "v", x = 0)
    private fun kitchen(m: Module, look: Look? = null, handle: String = "") = Furniture("k", "kitchen", walls = listOf("A"), modules = listOf(m), look = look, handle = handle)
    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }

    @Test fun aVitrinaIsAWallUnitWithGlassDoorsAndAGlassShelf() {
        val v = vitrina()
        assertEquals("wall", v.type); assertEquals(Fronts("door", 2), v.fronts)
        assertEquals(listOf(600, 720, 300, 1458), listOf(v.w, v.h, v.d, v.elev))
        assertTrue(v.glass && glassDoors(v)); assertFalse(v.accentIn)
        assertEquals(listOf(Insert("glass", qty = 1)), v.inserts)
        assertEquals("vitrina", kindOf(v))
        assertTrue("vitrina" in LIB_UP)
        // board doors again: board shelves, the wood accent inside goes with the glass
        val board = withGlassDoors(v.copy(accentIn = true), false)
        assertFalse(board.glass || board.accentIn || glassDoors(board))
        assertEquals(listOf(Insert("shelf", qty = 1)), board.inserts)
        assertEquals("wall", kindOf(board))
        // only a wall unit with doors takes glass
        assertFalse(withGlassDoors(template("open", ws, "A", 600), true).glass)
        assertFalse(withGlassDoors(template("base", ws, "A", 600), true).glass)
        assertFalse(glassDoors(v.copy(fronts = Fronts("open", 0))))
    }

    @Test fun noFrontBoardIsCutForAGlassDoor() {
        val v = vitrina()
        val ps = partsOf(v, ws)
        assertTrue(ps.none { it.role == "front" })
        assertTrue(ps.none { it.key == "fp.door" || it.key == "fp.shelf" })
        // the carcass is cut as usual: the same sides, top and bottom and back as the board wall unit's
        val board = withGlassDoors(v, false)
        val bp = partsOf(board, ws)
        assertEquals(bp.filter { it.role != "front" && it.key != "fp.shelf" }, ps)
        assertEquals(listOf(Triple(717, 297, 2)), bp.filter { it.key == "fp.door" }.map { Triple(it.L, it.W, it.qty) })
        assertEquals(listOf(Triple(720, 300, 2), Triple(568, 300, 2), Triple(716, 596, 1)), ps.map { Triple(it.L, it.W, it.qty) })
        // nor in the cut list of the kitchen
        assertTrue(cutList(listOf(kitchen(v)), ws).none { it.p.role == "front" })
    }

    @Test fun theGlassIsBoughtByTheSquareMetre() {
        val v = vitrina()
        val hw = hardwareOf(v, ws)
        // two doors 717 × 297 in their frames; one glass shelf 564 × 275
        assertEquals(2 * 717 * 297, hw["glassDoor"]); assertEquals(425898, hw["glassDoor"])
        assertEquals(155100, hw["glassShelf"]); assertEquals(4, hw["pin"])
        // hinges and handles as any door's
        assertEquals(4, hw["hingeSoft"]); assertEquals(2, hw["handle"]); assertNull(hw["push"])
        assertEquals(2, hw["hanger"]); assertEquals(16, hw["confirmat"])
        val f = kitchen(v)
        val gl = line(f, "glassDoor")!!
        assertEquals(0.43, gl.qty, 1e-9); assertEquals(BigInteger.valueOf(900000), gl.price); assertEquals(BigInteger.valueOf(387000), gl.amount)
        assertEquals(BigInteger.valueOf(48000), line(f, "glassShelf")!!.amount)
        // a board wall unit has none
        assertNull(hardwareOf(withGlassDoors(v, false), ws)["glassDoor"])
    }

    @Test fun theFlutedGlassIsPricedOnlyWhenOn() {
        val v = vitrina()
        val plain = kitchen(v, Look())
        val fluted = kitchen(v, Look(fglass = true))
        assertNull(hardware(listOf(plain), ws)["fglass"]); assertNull(line(plain, "fglass"))
        assertEquals(425898, hardware(listOf(fluted), ws)["fglass"])
        val fl = line(fluted, "fglass")!!
        assertEquals(0.43, fl.qty, 1e-9); assertEquals(BigInteger.valueOf(193500), fl.amount)
        // the glass itself is the same either way; a board wall unit takes no fluted glass
        assertEquals(line(plain, "glassDoor")!!.amount, line(fluted, "glassDoor")!!.amount)
        assertNull(hardware(listOf(kitchen(withGlassDoors(v, false), Look(fglass = true))), ws)["fglass"])
    }

    @Test fun pushLatchesWhenTheHandleTypeSaysSo() {
        val v = vitrina()
        // a Gola kitchen's wall units open by a push latch
        val gola = hardware(listOf(kitchen(v, handle = GOLA)), ws)
        assertEquals(2, gola["push"]); assertNull(gola["handle"]); assertEquals(4, gola["hingeSoft"])
        // without handles ("Tutqichsiz")
        val bare = hardwareOf(allHandles(v, false), ws)
        assertEquals(2, bare["push"]); assertNull(bare["handle"])
    }

    @Test fun anOlderKitchenSavesAsItWas() {
        val old = """{"id":"f1","kind":"kitchen","name":"Oshxona 1","roomId":null,"walls":["A"],"modules":[{"id":"m1","type":"wall","w":600,"h":720,"d":300,"x":0,"wall":"A","elev":1458,""" +
            """"fronts":{"kind":"door","n":2},"inserts":[{"kind":"shelf","pos":0,"qty":2,"h":0}],"sections":[],"legs":false,"soft":true,"handles":true,"label":"","app":"","sideL":true,"sideR":true,"slide":null,"base":null,"led":false,"opt":null}],""" +
            """"mats":{"carcass":"ldsp16w","front":"ldsp16k","back":"hdf3"},"created":0,"layout":"I","ws":"","free":null,"model":"","keep":false,""" +
            """"kx":null,"type":"","pose":null,"baseH":null,"hand":"","handle":""}"""
        val f = json.decodeFromString(Furniture.serializer(), old)
        val m = f.modules.single()
        assertFalse(m.glass || m.accentIn || glassDoors(m))
        assertEquals(old, json.encodeToString(Furniture.serializer(), f))
        // a vitrina writes its flags, and reads them back
        val g = f.copy(modules = listOf(withGlassDoors(m, true).copy(accentIn = true)))
        val out = json.encodeToString(Furniture.serializer(), g)
        assertTrue(out.contains("\"glass\":true") && out.contains("\"accentIn\":true") && out.contains("\"kind\":\"glass\",\"pos\":0,\"qty\":2"))
        assertEquals(g, json.decodeFromString(Furniture.serializer(), out))
        // glass without the accent: only the glass flag is written
        assertFalse(json.encodeToString(Module.serializer(), withGlassDoors(m, true)).contains("accentIn"))
    }

    @Test fun theDishesStandOnTheFloorAndTheGlassShelf() {
        val v = vitrina()
        // the shelf halfway up, as a board shelf is; three plates (three turned squares each) and four cups
        assertEquals(listOf(1810.0), vitrinaShelves(v, ws.t))
        val d = vitrinaDishes(v, ws.t)
        assertEquals(13, d.size)
        assertEquals(9, d.count { it.y0 < 1810 }); assertEquals(4, d.count { it.y0 >= 1816 })
        // a narrow one: one plate and one cup
        assertEquals(4, vitrinaDishes(vitrina(300), ws.t).size)
        // without a shelf: plates only
        assertEquals(9, vitrinaDishes(v.copy(inserts = emptyList()), ws.t).size)
    }
}
