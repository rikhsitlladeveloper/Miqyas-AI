package uz.metrx.app.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.furniture.AkApp
import uz.metrx.app.furniture.DESIGN_PRESETS
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.akPieces
import uz.metrx.app.furniture.akPlan
import uz.metrx.app.furniture.akSite
import uz.metrx.app.geo.Looks
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import java.io.ByteArrayInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import java.util.zip.ZipInputStream

/** The client's 3D files (Client3D.kt) of an auto kitchen in the mockup's room. */
class Client3DTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2800, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")),
        openings = listOf(Opening("w", "window", "A", 1200, 1250, 1000, 950), Opening("d", "door", "C", 800, 2050, 1300)),
        points = listOf(SitePoint("c", "cold", "A", 1600, 550), SitePoint("g", "gas", "B", 400, 1000)))

    private fun kitchen(preset: String, walls: List<String> = listOf("D", "A", "B"), layout: String = "U"): Furniture {
        val site = akSite(room, { null })
        return akPieces(akPlan(site, walls, layout, AkApp("bi", "tall"), preset, ws)!!, site, ws, listOf("Oshxona"))[0]
    }

    private fun meshFor(f: Furniture, boxes: Boolean = false): C3Mesh {
        val shell = buildShell(listOf(room), true)
        val fur = furniture3D(listOf(f), shell.bases, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS, light = true, ceil = 2700, decor = false, boxes = boxes)
        return meshOf(shell.parts.filter { it.role != Role.FURN } + fur.parts, shell.bases.mapValues { it.value.nx to it.value.nz })
    }

    private fun info(dims: Boolean = true, phone: Boolean = true, price: Boolean = true) = C3Info("Aliyevlar", "P-simon oshxona · 14 modul", "Oshxona 3,40 × 2,80 m · 26.10.2026",
        if (price) "Taxminiy narx: 41 200 000 so‘m" else null, "Sanjar", if (phone) "+998 90 000 00 00" else null,
        if (dims) listOf(C3Dim(V3(0.0, 2.6, .02), V3(3.4, 2.6, .02), "3,40 m")) else emptyList(),
        listOf(C3Wall("A", 0.0, 0.0, 0.0, 1.0)), "Aylantiring · kattalashtiring", "WebGL yo‘q", "Usta: Sanjar")

    @Test fun theHtmlHasEverythingInsideAndNoWebAddress() {
        for (p in DESIGN_PRESETS) {
            val html = clientHtml(meshFor(kitchen(p.id)), info())
            assertFalse(p.id, Regex("https?://", RegexOption.IGNORE_CASE).containsMatchIn(html))
            assertFalse(html.contains("<script src") || html.contains("<link") || html.contains("@import") || html.contains("url("))
            assertTrue(html.startsWith("<!doctype html>"))
            assertTrue(html.contains("window.MODEL=") && html.contains("METRX") && html.contains("Aliyevlar") && html.contains("tel:+998900000000"))
            // under 2 MB with the shaped details (a U kitchen of 3 walls, the room round it)
            assertTrue("${p.id}: ${html.length}", html.toByteArray().size < 2_000_000)
            println("SIZE ${p.id} html=${html.toByteArray().size} usdz=${usdzOf(meshFor(kitchen(p.id)), "x").size} tris=${meshFor(kitchen(p.id)).triangles}")
        }
        val bare = clientHtml(meshFor(kitchen("twotone")), info(phone = false, price = false))
        assertFalse(bare.contains("tel:")); assertFalse(bare.contains("Taxminiy"))
        // the model's numbers round trip: the first group's first corner in mm
        val mesh = meshFor(kitchen("twotone"))
        val g = mesh.groups.first()
        val b64 = Regex("\\[${g.mat},(null|\"[A-Z]\"),${g.verts},\"([^\"]+)\"").find(clientHtml(mesh, info()))!!.groupValues[2]
        val bb = ByteBuffer.wrap(java.util.Base64.getDecoder().decode(b64)).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(Math.round(g.pos[0] * 1000).toInt(), bb.short.toInt())
        assertEquals(g.verts * 6, java.util.Base64.getDecoder().decode(b64).size)
    }

    @Test fun theUsdzIsAStoredAlignedZipWithTheLayerFirst() {
        val mesh = meshFor(kitchen("neo"))
        val z = usdzOf(mesh, "Aliyevlar")
        // the local header: stored, its data at a multiple of 64
        val bb = ByteBuffer.wrap(z).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x04034b50, bb.getInt(0))
        assertEquals(0, bb.getShort(8).toInt())                       // stored, not deflated
        val nameLen = bb.getShort(26).toInt(); val extra = bb.getShort(28).toInt()
        assertEquals("model.usda", String(z, 30, nameLen, Charsets.UTF_8))
        val dataAt = 30 + nameLen + extra
        assertEquals(0, dataAt % 64)
        val size = bb.getInt(22)
        val data = z.copyOfRange(dataAt, dataAt + size)
        assertEquals(CRC32().apply { update(data) }.value.toInt(), bb.getInt(14))
        val text = String(data, Charsets.UTF_8)
        assertTrue(text.startsWith("#usda 1.0"))
        assertTrue(text.contains("defaultPrim = \"Root\"") && text.contains("upAxis = \"Y\"") && text.contains("metersPerUnit = 1"))
        assertTrue(text.contains("UsdPreviewSurface"))
        assertEquals(mesh.groups.size, Regex("def Mesh ").findAll(text).count())
        assertEquals(mesh.mats.size, Regex("def Material ").findAll(text).count())
        // the end of central directory points at the one entry
        val eocd = z.size - 22
        assertEquals(0x06054b50, bb.getInt(eocd)); assertEquals(1, bb.getShort(eocd + 10).toInt())
        val cd = bb.getInt(eocd + 16)
        assertEquals(0x02014b50, bb.getInt(cd)); assertEquals(0, bb.getInt(cd + 42))
        // java's own zip reader reads it back
        ZipInputStream(ByteArrayInputStream(z)).use { zin ->
            val e = zin.nextEntry!!
            assertEquals("model.usda", e.name)
            assertEquals(text, zin.readBytes().toString(Charsets.UTF_8))
        }
        // two files: each aligned
        val two = usdz(listOf(ZipFile("a.usda", "#usda 1.0\n".toByteArray()), ZipFile("tex/b.png", ByteArray(77) { it.toByte() })))
        var at = 0
        repeat(2) {
            val b2 = ByteBuffer.wrap(two).order(ByteOrder.LITTLE_ENDIAN)
            assertEquals(0x04034b50, b2.getInt(at))
            val n = b2.getShort(at + 26).toInt(); val x = b2.getShort(at + 28).toInt(); val s = b2.getInt(at + 22)
            assertEquals(0, (at + 30 + n + x) % 64)
            at += 30 + n + x + s
        }
    }

    @Test fun theMeshKeepsTheLooksApart() {
        val mesh = meshFor(kitchen("twotone"))
        assertTrue(mesh.mats.size > 3)
        assertTrue(mesh.groups.all { it.pos.size == it.nrm.size && it.pos.size % 9 == 0 })
        // walls are their own groups, the furniture's bounds inside the room
        assertTrue(mesh.groups.map { it.wall }.distinct().toString(), mesh.groups.any { it.wall == "A" })
        val f = mesh.focus
        // (the scene's x starts past wall D's thickness)
        assertTrue(f.toList().toString(), f[3] - f[0] <= 3.41 && f[5] - f[2] <= 2.81 && f[4] <= 2.7)
        assertTrue(meshFor(kitchen("twotone"), boxes = true).triangles < mesh.triangles)
        // one side a face: each triangle wound counter-clockwise seen from where its normal points
        mesh.groups.forEach { gr ->
            for (t in 0 until gr.verts / 3) {
                val i = t * 9
                val ax = gr.pos[i + 3] - gr.pos[i]; val ay = gr.pos[i + 4] - gr.pos[i + 1]; val az = gr.pos[i + 5] - gr.pos[i + 2]
                val bx = gr.pos[i + 6] - gr.pos[i]; val by = gr.pos[i + 7] - gr.pos[i + 1]; val bz = gr.pos[i + 8] - gr.pos[i + 2]
                assertTrue((ay * bz - az * by) * gr.nrm[i] + (az * bx - ax * bz) * gr.nrm[i + 1] + (ax * by - ay * bx) * gr.nrm[i + 2] >= -1e-6f)
            }
        }
        // the walls keep their inside faces only: fewer triangles than with every face
        val shell = buildShell(listOf(room), true)
        assertTrue(meshOf(shell.parts.filter { it.role == Role.WALL }, shell.bases.mapValues { it.value.nx to it.value.nz }).triangles < meshOf(shell.parts.filter { it.role == Role.WALL }).triangles)
        assertTrue(usda(mesh).contains("doubleSided = 0"))
        assertTrue(clientHtml(mesh, info()).contains("gl.enable(gl.CULL_FACE)"))
    }
}
