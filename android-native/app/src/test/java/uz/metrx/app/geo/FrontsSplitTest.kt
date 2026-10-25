package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.DESIGN_PRESETS
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.GALLERY
import uz.metrx.app.furniture.KExtras
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withPreset
import kotlin.math.abs
import kotlin.math.roundToLong

/**
 * Doors and drawers that move without a rebuild (Fronts3D.kt): the split build, each front built shut and moved by its
 * transform, draws exactly what the full rebuild at that openness drew (same faces, outlines and tap boxes), and the
 * rest of the piece does not change while they open.
 */
class FrontsSplitTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val shell = buildShell(listOf(room), true)

    private fun kitchen(preset: String, style: String? = null): Furniture {
        val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L", kx = KExtras(splash = 600, plinth = true))
        val f = withPreset(autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList()), preset)
        return if (style != null) withLook(f) { it.copy(style = style) } else f
    }

    /** The full rebuild with each front [amt] of the way open (the old path), or the split build ([split]). */
    private fun build(f: Furniture, bases: Map<String, WallBasis>, rich: Boolean, light: Boolean = false, amt: (String) -> Double = { 0.0 }, split: Boolean = false, bare: Boolean = false) =
        if (rich) furniture3D(listOf(f), bases, ws, { 0xCDBFAE }, emptySet(), amt = amt, look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS, light = light,
            ceil = 2700, split = split, bare = bare)
        else furniture3D(listOf(f), bases, ws, { 0xCDBFAE }, emptySet(), amt = amt, split = split, bare = bare)

    // an odd offset keeps whole and half millimetres off the rounding boundaries
    private fun r(v: Double, k: Double = 1e4) = (v * k + .2718281).roundToLong()
    private fun pt(p: V3) = "${r(p.x)},${r(p.y)},${r(p.z)}"
    private fun faceKey(look: Any?, f: Face, rg: Rigid?): String {
        val pts = if (rg == null) f.pts else f.pts.map { rg.point(it) }
        val n = if (rg == null) f.n else rg.dir(f.n)
        return "$look|${r(n.x, 1e3)},${r(n.y, 1e3)},${r(n.z, 1e3)}|" + pts.joinToString(";") { pt(it) }
    }
    private fun segKeys(e: Edges, rg: Rigid?) = e.segs.map { if (rg == null) it else rg.point(it) }.chunked(2).map { (a, b) -> "${e.rgb}|${pt(a)}>${pt(b)}" }
    private fun boxKey(p: Pick) = "${p.key}|${pt(p.box.o)}|${pt(p.box.a)}|${pt(p.box.b)}|${pt(p.box.c)}"

    private class Scene(val faces: List<String>, val segs: List<String>, val picks: List<String>)

    private fun Part.keys(rg: Rigid?) = faces.map { faceKey(look ?: rgb, it, rg) }

    /** What the full rebuild draws. */
    private fun whole(d: Furn3D) = Scene(d.parts.flatMap { it.keys(null) }.sorted(), d.edges.flatMap { segKeys(it, null) }.sorted(), d.picks.map { boxKey(it) }.sorted())

    /** What the 3D draws from the split build with the fronts [amt] open: the rest as built, each front moved, toggles shown or not. */
    private fun moved(d: Furn3D, amt: (String) -> Double): Scene {
        val faces = ArrayList<String>(); val segs = ArrayList<String>()
        d.parts.forEach { faces += it.keys(null) }; d.edges.forEach { segs += segKeys(it, null) }
        d.fronts.forEach { fr ->
            val k = amt(fr.key); val rg = fr.at(k)
            (fr.parts + if (k > 0) fr.inner else emptyList()).forEach { faces += it.keys(rg) }
            (fr.edges + if (k > 0) fr.innerEdges else emptyList()).forEach { segs += segKeys(it, rg) }
        }
        d.toggles.filter { it.shown(amt) }.forEach { t -> t.parts.forEach { faces += it.keys(null) }; t.edges.forEach { segs += segKeys(it, null) } }
        return Scene(faces.sorted(), segs.sorted(), d.picksAt(amt).map { boxKey(it) }.sorted())
    }

    private fun assertSame(what: String, a: Scene, b: Scene) {
        assertEquals("$what faces", a.faces.size, b.faces.size)
        val diff = a.faces.zip(b.faces).firstOrNull { it.first != it.second }
        assertTrue("$what faces differ: $diff", diff == null)
        assertEquals("$what outlines", a.segs, b.segs)
        assertEquals("$what tap boxes", a.picks, b.picks)
    }

    /** [f] split and moved matches the full rebuild with every front shut, half open, open, and in a mix. */
    private fun check(id: String, f: Furniture, bases: Map<String, WallBasis>, rich: Boolean, light: Boolean = false) {
        val split = build(f, bases, rich, light, split = true)
        val keys = split.keys
        assertEquals("$id: every key a front", keys.toSet(), split.fronts.map { it.key }.toSet())
        val staticParts = split.parts.size; val staticFaces = split.parts.sumOf { it.faces.size }
        val mixes: List<(String) -> Double> = listOf({ _ -> 0.0 }, { _ -> .5 }, { _ -> 1.0 },
            { k -> listOf(0.0, .3, 1.0)[abs(k.hashCode()) % 3] }, { k -> listOf(.01, .7)[abs(k.hashCode()) % 2] })
        mixes.forEachIndexed { i, amt ->
            assertSame("$id ($rich, $light) mix $i", whole(build(f, bases, rich, light, amt)), moved(split, amt))
        }
        // the rest stays put: the split build reads no openness, its parts are those whatever is open
        val again = build(f, bases, rich, light, amt = { 1.0 }, split = true)
        assertEquals(staticParts, again.parts.size); assertEquals(staticFaces, again.parts.sumOf { it.faces.size })
    }

    @Test fun kitchensMovedMatchTheFullRebuild() {
        listOf(kitchen("twotone"), kitchen("neo"), kitchen("neo", "fluted"), kitchen("gola"), kitchen("dark"), kitchen("gloss")).forEach { k ->
            check("kitchen ${k.look?.preset} ${k.look?.style}", k, shell.bases, rich = true)
            check("kitchen ${k.look?.preset} light", k, shell.bases, rich = true, light = true)
        }
        check("kitchen plain", kitchen("twotone"), shell.bases, rich = false)
    }

    @Test fun everyGalleryPieceMovedMatchesTheFullRebuild() {
        GALLERY.flatMap { it.second }.forEach { id ->
            val base = pieceOf(fModel(id)!!, emptyMap(), ws, id)
            val sh = buildShell(listOf(freeRoom(base)), true, true)
            check("$id plain", base, sh.bases, rich = false)
            listOf("twotone", "neo").forEach { pr ->
                val f = withPreset(base, pr, fresh = true)
                check("$id $pr", f, sh.bases, rich = true)
            }
        }
    }

    @Test fun kupeLedWardrobesRacksAndLiftBedsToo() {
        val kupe = withPreset(pieceOf(fModel("s3")!!, mapOf("w" to 2400, "h" to 2600, "d" to 620), ws, "Kupe"), "twotone", fresh = true)
        val hinged = withLook(withPreset(pieceOf(fModel("h3")!!, mapOf("w" to 1500, "h" to 2400, "d" to 600), ws, "Shkaf"), "neo", fresh = true)) { it.copy(led = true) }
        val lift = withPreset(pieceOf(fModel("bed")!!, mapOf("bt" to 2), ws, "Karavot"), "twotone", fresh = true)
        val hall = withPreset(pieceOf(fModel("hallway")!!, emptyMap(), ws, "hall"), "twotone", fresh = true)
        listOf(withLook(kupe) { it.copy(led = true) }, hinged, lift, hall).forEach { f ->
            val sh = buildShell(listOf(freeRoom(f)), true, true)
            check(f.type.ifEmpty { f.kind }, f, sh.bases, rich = true)
            check("${f.type} light", f, sh.bases, rich = true, light = true)
            check("${f.type} plain", f, sh.bases, rich = false)
        }
        // the LED with door sensors is a toggle, lit while a door is open; a rack and the lift-up base are fronts
        val sh = buildShell(listOf(freeRoom(hinged)), true, true)
        val split = build(hinged, sh.bases, true, split = true)
        assertTrue(split.toggles.any { it.whenOpen } && split.toggles.any { !it.whenOpen })
        val dl = split.toggles.first { it.whenOpen }
        assertTrue(!dl.shown { 0.0 } && dl.shown { k -> if (k == dl.deps.first()) .5 else 0.0 })
        assertTrue(build(lift, buildShell(listOf(freeRoom(lift)), true, true).bases, true, split = true).fronts.any { it.key.endsWith(":lift") && it.motion.angle > .6 })
        assertTrue(build(hall, buildShell(listOf(freeRoom(hall)), true, true).bases, true, split = true).fronts.any { ":r" in it.key })
        // seeing inside: no doors or drawer fronts at all, the drawers' boxes shut in the rest
        val bareS = build(hinged, sh.bases, true, split = true, bare = true)
        assertSame("bare", whole(build(hinged, sh.bases, true, bare = true)), moved(bareS) { 0.0 })
    }

    @Test fun aDoorTurnsAboutItsHingeAndADrawerPullsStraightOut() {
        val k = kitchen("twotone")
        val split = build(k, shell.bases, true, split = true)
        val door = split.fronts.first { it.motion.angle > 0 && it.key.endsWith(":f0") }
        // the hinge line stays where it is, at any openness
        listOf(0.0, .5, 1.0).forEach { t ->
            val p = door.at(t).point(door.motion.pivot); assertTrue(t.toString(), (p - door.motion.pivot).len() < 1e-12)
            val q = door.motion.pivot + V3(0.0, .7, 0.0); assertTrue((door.at(t).point(q) - q).len() < 1e-12)
        }
        // a few vertices of the door at 0, half and fully open: the same as the full rebuild's tap box corners there
        listOf(0.0, .5, 1.0).forEach { t ->
            val old = build(k, shell.bases, true, amt = { if (it == door.key) t else 0.0 }).picks.single { it.key == door.key }.box
            val shut = door.picks.single().box
            val rg = door.at(t)
            old.corners().zip(rg.obb(shut).corners()).forEach { (a, b) -> assertTrue("$t: $a vs $b", (a - b).len() < 1e-9) }
        }
        // fully open it turns the door's 90° (beside a wall or a neighbour) about the vertical
        assertEquals(Math.PI / 2, door.motion.angle, 1e-12); assertTrue(abs(abs(door.motion.axis.y) - 1) < 1e-12)
        // a dresser's drawer: straight out of its wall, no turn, half as far half open; its box only shows while out
        val dr = withPreset(pieceOf(fModel("dresser")!!, emptyMap(), ws, "dresser"), "twotone", fresh = true)
        val b = buildShell(listOf(freeRoom(dr)), true, true).bases
        val ds = build(dr, b, true, split = true)
        val drawer = ds.fronts.first { it.motion.angle == 0.0 && it.inner.isNotEmpty() }
        val out = drawer.at(1.0).t
        val w = b.getValue(dr.walls.first())
        assertTrue(out.len() > .2 && abs(out.y) < 1e-12 && abs(out.dot(V3(w.nx, 0.0, w.nz)) - out.len()) < 1e-9)
        assertTrue((drawer.at(.5).t - out * .5).len() < 1e-12)
        listOf(0.0, .5, 1.0).forEach { t ->
            val old = build(dr, b, true, amt = { if (it == drawer.key) t else 0.0 }).picks.single { it.key == drawer.key }.box
            old.corners().zip(drawer.at(t).obb(drawer.picks.single().box).corners()).forEach { (p, q) -> assertTrue("$t: $p vs $q", (p - q).len() < 1e-9) }
        }
    }

    @Test fun designPresetsAllSplit() {
        DESIGN_PRESETS.forEach { pr -> check("kitchen ${pr.id}", kitchen(pr.id), shell.bases, rich = true) }
    }

    /**
     * The cost of one animation step on the JVM (geometry only): before, the whole piece rebuilt; now, the moving
     * fronts' transforms and the tap boxes. Printed for the report; asserts only that a step is now cheaper.
     */
    @Test fun aStepCostsLessThanARebuild() {
        val rows = ArrayList<String>()
        listOf("twotone" to null, "neo" to null, "neo" to "fluted").forEach { (pr, st) ->
            val k = kitchen(pr, st)
            fun rebuild(t: Double) = build(k, shell.bases, true, amt = { if (it.endsWith(":f0")) t else 0.0 })
            repeat(5) { rebuild(.5) }
            val n = 20
            var t0 = System.nanoTime(); repeat(n) { rebuild(it / n.toDouble()) }
            val before = (System.nanoTime() - t0) / n / 1e6
            t0 = System.nanoTime(); val split = build(k, shell.bases, true, split = true); val once = (System.nanoTime() - t0) / 1e6
            val moving = split.fronts.filter { it.key.endsWith(":f0") }
            repeat(200) { s -> moving.forEach { it.at(s / 200.0).columns() }; split.picksAt { if (it.endsWith(":f0")) s / 200.0 else 0.0 } }
            val m = 2000
            t0 = System.nanoTime(); repeat(m) { s -> val a = s / m.toDouble(); moving.forEach { it.at(a).columns() }; split.picksAt { if (it.endsWith(":f0")) a else 0.0 } }
            val after = (System.nanoTime() - t0) / m / 1e6
            val ent = split.fronts.sumOf { f -> f.parts.size + f.edges.size + f.inner.size + f.innerEdges.size } + split.toggles.sumOf { it.parts.size + it.edges.size }
            rows += "%s/%s: rebuild per step %.2f ms; split build once %.2f ms; step now %.4f ms (%d moving fronts); static parts %d + outlines %d, fronts %d with %d entities (the full build: %d parts + %d outlines)"
                .format(java.util.Locale.ROOT, pr, st ?: "-", before, once, after, moving.size, split.parts.count { it.faces.isNotEmpty() }, split.edges.size, split.fronts.size, ent, rebuild(0.0).parts.count { it.faces.isNotEmpty() }, rebuild(0.0).edges.size)
            assertTrue(after < before)
        }
        println("FRONTS-TIMING\n" + rows.joinToString("\n"))
        java.io.File("build/fronts-timing.txt").writeText(rows.joinToString("\n"))
    }
}
