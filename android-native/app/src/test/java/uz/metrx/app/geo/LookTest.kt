package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.runsOf
import java.io.File
import kotlin.math.abs

/** The lit 3D's looks and texture coordinates (modern 3D part 1). */
class LookTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val shell = buildShell(listOf(room), true)
    private fun kitchen(): Furniture {
        val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L")
        return autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList())
    }

    @Test fun everyFurniturePartHasALookAndEveryFaceItsUvs() {
        val fr = furniture3D(listOf(kitchen()), shell.bases, ws, { 0xCDBFAE }, emptySet())
        assertTrue(fr.parts.isNotEmpty())
        fr.parts.forEach { p ->
            assertNotNull(p.look)
            p.faces.forEach { f -> assertEquals(f.pts.size * 2, f.uv?.size) }
        }
        // a box still brings its six faces one after another (the 2D painter reads them six at a time)
        fr.parts.forEach { assertEquals(0, it.faces.size % 6) }
    }

    @Test fun partsStayOnePerWallAndLook() {
        // the same board for carcass and fronts is one part per wall, as one colour was before
        val fr = furniture3D(listOf(kitchen()), shell.bases, ws, { 0xCDBFAE }, emptySet())
        val keys = fr.parts.map { (it.wall to it.look) to it.slab }
        assertEquals(keys.size, keys.toSet().size)
        // a decor picture and a finish make their own part; a plain colour stays as it was
        val wood = furniture3D(listOf(kitchen()), shell.bases, ws, { 0xCDBFAE }, emptySet(), look = { id -> Looks.board(0xA47B54, if (id == kitchen().mats.front) "oak_halifax" else null) })
        assertTrue(wood.parts.any { it.look?.tex == "oak_halifax" })
    }

    @Test fun doorGrainRunsUpAndUvsAreInMetres() {
        val f = kitchen()
        val fr = furniture3D(listOf(f), shell.bases, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xA47B54, "oak_halifax") })
        val door = fr.picks.first { it.key.endsWith(":f0") && it.box.b.len() > it.box.a.len() && abs(it.box.b.y) > .1 }.box
        // the door's front face (the a × b face): u follows the height (b, up), v the width
        val part = fr.parts.first { p -> p.faces.any { it.pts.contains(door.o) && it.pts.contains(door.o + door.a) && it.pts.contains(door.o + door.b) } }
        val face = part.faces.first { it.pts.contains(door.o) && it.pts.contains(door.o + door.a) && it.pts.contains(door.o + door.b) }
        val uv = face.uv!!
        val iO = face.pts.indexOf(door.o); val iB = face.pts.indexOf(door.o + door.b); val iA = face.pts.indexOf(door.o + door.a)
        assertEquals(door.b.len(), uv[2 * iB] - uv[2 * iO], 1e-6)       // along u: the door's height, metres
        assertEquals(0.0, uv[2 * iA] - uv[2 * iO], 1e-6)
        assertEquals(door.a.len(), abs(uv[2 * iA + 1] - uv[2 * iO + 1]), 1e-6)
    }

    @Test fun planarUvsFollowTheFloorAndWalls() {
        val floor = Face(V3(0.0, 1.0, 0.0), listOf(V3(0.0, 0.0, 0.0), V3(2.0, 0.0, 0.0), V3(2.0, 0.0, 3.0)))
        assertEquals(listOf(0.0, 0.0, 2.0, 0.0, 2.0, 3.0), planarUv(floor).toList())
        val wall = Face(V3(0.0, 0.0, 1.0), listOf(V3(1.0, 0.0, 0.0), V3(1.0, 2.5, 0.0)))
        assertEquals(listOf(1.0, 0.0, 1.0, 2.5), planarUv(wall).toList())
    }

    @Test fun looksForTheWorkshopsMaterials() {
        assertEquals("marble_white", Looks.of("worktop", 0xE5E2DD, "marble_white").tex)
        assertTrue(Looks.of("worktop", 0xE5E2DD, "marble_white").clear > 0f)
        assertTrue(Looks.of("board", 0xF2F2EF, finish = "gloss").rough < .2f)
        assertTrue(Looks.of("board", 0xF2F2EF).rough > .6f)
        // a mirror and chrome get duller on the light tier, where there are no sharp reflections to show
        assertTrue(Looks.steel.light().metal < .5f && Looks.steel.light().rough >= .3f)
        assertEquals(Looks.lamel, Looks.lamel.light())
    }

    @Test fun everyTextureIsBundledInBothSizes() {
        val dir = listOf(File("src/main/assets/tex"), File("app/src/main/assets/tex")).first { it.exists() }
        TEXTURES.forEach { (id, t) ->
            assertTrue(id, File(dir, "512/${t.file}.webp").exists())
            assertTrue(id, File(dir, "256/${t.file}.webp").exists())
        }
        val src = File(dir, "SOURCES.md").readText()
        assertTrue(src.contains("CC0"))
        // no picture that nothing names, and each one listed
        File(dir, "512").listFiles()!!.forEach { assertTrue(it.name, it.nameWithoutExtension in TEX_FILES); assertTrue(it.name, src.contains("`${it.name}`")) }
        File(dir, "256").listFiles()!!.forEach { assertTrue(it.name, it.nameWithoutExtension in TEX_FILES) }
        assertFalse(TEXTURES.isEmpty())
    }
}
