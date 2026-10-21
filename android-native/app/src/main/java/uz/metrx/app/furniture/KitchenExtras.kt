package uz.metrx.app.furniture

import kotlinx.serialization.Serializable

/*
 * Kitchen extras (furniture plan section 7, Stage 1b-1): the worktop's corner joints, its cut-outs for the sink and the
 * hob and its end strips; the backsplash panel; the plinth; the cornice over the wall units; the LED strip under them;
 * end panels at the open ends of the rows. They go into the cut list, the hardware list and the cost. Pure Kotlin,
 * unit-tested (KitchenExtrasTest). Every rule is a default for the founder's furniture makers to check.
 */

/**
 * A kitchen's extras: [joint] "butt" or "mitre" (45°) where the worktop turns a corner; [cutouts] for the sink and the
 * hob; [splash] the backsplash height in mm (0: none); [plinth], [cornice], [led]; [ends] and [endsUp] end panels on the
 * lower and the upper row. A kitchen without them (made before Stage 1b) has none.
 */
@Serializable
data class KExtras(
    val joint: String = "butt",
    val cutouts: Boolean = true,
    val splash: Int = 0,
    val plinth: Boolean = false,
    val cornice: Boolean = false,
    val led: Boolean = false,
    val ends: Int = 0,
    val endsUp: Int = 0
)

/** What a new kitchen starts with: the plinth and one end panel a row where it ends in the room (an island has two more). */
fun kExtrasFor(layout: String) = KExtras(plinth = true, ends = when (layout) { "U" -> 0; "O" -> 3; "P" -> 2; else -> 1 }, endsUp = if (layout == "U") 0 else 1)

/** The worktop's corners: two runs one after the other on walls, both with worktop on them. */
fun worktopJoints(f: Furniture): Int {
    val runs = worktopRuns(f)
    return f.walls.indices.count { i -> i > 0 && f.walls[i] != ISLAND && f.walls[i - 1] != ISLAND && (runs[f.walls[i]] ?: 0) > 0 && (runs[f.walls[i - 1]] ?: 0) > 0 }
}

/** The plinth's length: the lower row's fronts (base and tall units, the dishwasher, fillers), mm. */
fun plinthMm(f: Furniture): Int = f.modules.filter { !isUpper(it) && (it.type == "base" || it.type == "tall" || it.type == "filler" || it.app == "dishwasher") }.sumOf { it.w }

/** The wall units' length (the cornice on top, the LED strip under them), mm. */
fun wallUnitsMm(f: Furniture): Int = f.modules.filter { it.type == "wall" }.sumOf { it.w }

/** The backsplash's length: the worktop along walls (not on the island), mm. */
fun splashMm(f: Furniture): Int = worktopRuns(f).filterKeys { it != ISLAND }.values.sum()

/** End panels as parts: the lower ones from the floor to the worktop, the upper ones the wall units' height. */
fun extrasParts(f: Furniture, ws0: Workshop): List<FPart> {
    val ws = wsOf(f, ws0)
    val x = f.kx ?: return emptyList()
    val out = ArrayList<FPart>()
    val all = 2 to 2
    fun part(key: String, a: Int, b: Int, n: Int) { if (n > 0) out += FPart(key, f.id, "front", maxOf(a, b), minOf(a, b), n, Bands(all.first, all.second, all.first, all.second), grain = true) }
    part("fp.endLow", ws.legH + K_BASE_H, K_BASE_D + 20, x.ends)
    part("fp.endUp", K_WALL_H, K_WALL_D + 20, x.endsUp)
    return out
}

/** The extras in the hardware list: kinds counted like the modules' (metre kinds in mm). */
fun extrasHardware(f: Furniture): Map<String, Int> {
    val x = f.kx ?: return emptyMap()
    val n = LinkedHashMap<String, Int>()
    fun add(k: String, v: Int) { if (v > 0) n[k] = (n[k] ?: 0) + v }
    val joints = worktopJoints(f)
    add(if (x.joint == "mitre") "wtMitre" else "wtJoint", joints)
    if (x.cutouts) add("wtCut", f.modules.count { it.app == "sink" || it.app == "hob" })
    // each worktop piece has two ends; a corner joins two of them
    val pieces = worktopRuns(f).values.count { it > 0 }
    add("wtEnd", 2 * pieces - 2 * joints)
    if (x.plinth) { add("plinthK", plinthMm(f)); add("plinthCorner", joints) }
    if (x.cornice) add("cornice", wallUnitsMm(f))
    if (x.led) { val mm = wallUnitsMm(f); add("led", mm); add("ledPsu", if (mm > 0) (mm + 4999) / 5000 else 0) }
    return n
}
