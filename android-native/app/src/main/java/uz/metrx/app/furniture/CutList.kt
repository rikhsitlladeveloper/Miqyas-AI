package uz.metrx.app.furniture

/*
 * The cut list (furniture plan section 6.4): an order's parts by material, equal parts added up, with the size to cut
 * (the finished size less the thick banding on each banded edge) and the banding to buy.
 */

/** One cut list line: [p] the part (finished size), [cutL] × [cutW] what the saw cuts, [mat] the material id. */
data class CutRow(val p: FPart, val mat: String, val cutL: Int, val cutW: Int)

/** Which material a role uses in a piece of furniture; [upper] fronts take a two-tone kitchen's upper board ([FMats.frontUp]). */
fun matFor(role: String, m: FMats, upper: Boolean = false) = when (role) { "front" -> if (upper) m.frontUp ?: m.front else m.front; "back" -> m.back; else -> m.carcass }

/** Every part of an order's furniture, equal ones (same part, size, banding and material) on one line. */
fun cutList(fs: List<Furniture>, ws: Workshop): List<CutRow> {
    val rows = LinkedHashMap<Pair<String, FPart>, Int>()
    fs.forEach { f ->
        // the upper end panels go with the upper fronts
        (f.modules.flatMap { m -> partsOf(m, wsOf(f, ws)).map { it to isUpperFront(f, m) } } + extrasParts(f, ws).map { it to (it.key == "fp.endUp") }).forEach { (p, up) ->
            val k = matFor(p.role, f.mats, up) to p.copy(mod = "", qty = 0)
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
