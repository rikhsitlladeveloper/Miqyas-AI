package uz.metrx.app.furniture

/*
 * The cut list (furniture plan section 6.4): an order's parts by material, equal parts added up, with the size to cut
 * (the finished size less the thick banding on each banded edge) and the banding to buy.
 */

/** One cut list line: [p] the part (finished size), [cutL] × [cutW] what the saw cuts, [mat] the material id. */
data class CutRow(val p: FPart, val mat: String, val cutL: Int, val cutW: Int)

/** Which material a role uses in a piece of furniture; [upper] fronts take a two-tone kitchen's upper board ([FMats.frontUp]). */
fun matFor(role: String, m: FMats, upper: Boolean = false) = when (role) { "front" -> if (upper) m.frontUp ?: m.front else m.front; "back" -> m.back; else -> m.carcass }

/** A bunk's or loft bed's ladder and guards (founder, 25 Oct 2026): cut from the look's wood accent, else the fronts' board. */
val ACCENT_KEYS = setOf("fp.ladder", "fp.rung", "fp.guard")

fun accentPart(m: Module, key: String) = (m.type == "bunk" || m.type == "loft") && key in ACCENT_KEYS

/**
 * The board part [p] of [f]'s box [m] is cut from (the 3D draws it so too): its role's, the upper fronts' for an upper
 * box and for a sliding door's filling over its split rail; a bunk's or loft bed's ladder and guards the look's wood
 * accent (a wd_ board), else the fronts'.
 */
fun partMat(f: Furniture, m: Module, p: FPart): String =
    if (accentPart(m, p.key)) f.look?.accent?.takeIf { it.isNotEmpty() } ?: f.mats.front
    else matFor(p.role, f.mats, isUpperFront(f, m) || p.key == "fp.slideUp")

/**
 * Every part of [f] with the board it is cut from: its boxes' (partMat; a metal ladder's stringers and rungs are bought,
 * not cut: Look.kt metalLadder), then a kitchen's extras (the upper end panels with the upper fronts).
 */
fun partsWithMat(f: Furniture, ws: Workshop): List<Pair<FPart, String>> =
    f.modules.flatMap { m -> partsOf(m, wsOf(f, ws)).filterNot { metalLadder(f, m) && it.key in LADDER_KEYS }.map { it to partMat(f, m, it) } } +
        extrasParts(f, ws).map { it to matFor(it.role, f.mats, it.key == "fp.endUp") }

/** Every part of an order's furniture, equal ones (same part, size, banding and material) on one line. */
fun cutList(fs: List<Furniture>, ws: Workshop): List<CutRow> {
    val rows = LinkedHashMap<Pair<String, FPart>, Int>()
    fs.forEach { f ->
        partsWithMat(f, ws).forEach { (p, mat) ->
            val k = mat to p.copy(mod = "", qty = 0)
            rows[k] = (rows[k] ?: 0) + p.qty
        }
    }
    return rows.map { (k, n) ->
        val p = k.second.copy(qty = n)
        val off = if (ws.bandOff) ws.band10 else 0
        fun less(a: Int, e1: Int, e2: Int) = (a * 10 - (if (e1 == 2) off else 0) - (if (e2 == 2) off else 0)) / 10
        // thick banding on the short edges shortens the length; on the long edges it narrows the width
        CutRow(p, k.first, less(p.L, p.bands.s1, p.bands.s2), less(p.W, p.bands.l1, p.bands.l2))
    }.sortedWith(compareBy({ it.mat }, { -it.p.L }, { -it.p.W }))
}

/** Banding to buy, metres of thick and of thin: every banded edge plus 30 mm for trimming. */
fun bandMetres(rows: List<CutRow>): Pair<Double, Double> {
    var thick = 0L; var thin = 0L
    rows.forEach { r ->
        val b = r.p.bands
        fun add(code: Int, len: Int) { val mm = (len + 30L) * r.p.qty; if (code == 2) thick += mm else if (code == 1) thin += mm }
        add(b.l1, r.p.L); add(b.l2, r.p.L); add(b.s1, r.p.W); add(b.s2, r.p.W)
    }
    return thick / 1000.0 to thin / 1000.0
}
