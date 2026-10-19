package uz.metrx.app.furniture

/*
 * Hardware counting (furniture plan section 6.6). Keys are [Hw.kind]s; "rail" is counted in millimetres of rail.
 * Every rule is a default for the founder's furniture makers to check.
 */

fun hardwareOf(m: Module, ws: Workshop): Map<String, Int> {
    val n = HashMap<String, Int>()
    fun add(k: String, v: Int) { if (v > 0) n[k] = (n[k] ?: 0) + v }
    val hinge = if (m.soft) "hingeSoft" else "hinge"
    fun fronts(f: Fronts, w: Int, h: Int) {
        val fs = frontSizes(f, w, h, ws)
        when (f.kind) {
            "door" -> fs.forEach { (fh, _) -> add(hinge, hingesFor(fh)); if (m.handles) add("handle", 1) }
            "drawer" -> { add("runner", fs.size); if (m.handles) add("handle", fs.size) }
        }
    }
    fun inside(ins: List<Insert>, iw: Int) {
        ins.forEach { x ->
            when (x.kind) {
                "shelf" -> add("pin", 4 * x.qty)
                "rail" -> { add("rail", iw); add("railEnd", 2) }
                "drawer", "trouser", "shoe" -> add("runner", 1)
                "lift" -> add("lift", 1)
            }
        }
    }
    val t = ws.t
    if (m.type == "gap" || m.type == "filler") return n
    when (m.type) {
        "wardrobe" -> {
            val secs = m.sections.ifEmpty { listOf(Section(m.w)) }
            secs.forEachIndexed { i, s -> fronts(s.fronts, s.w, m.h - wardBase(m)); inside(s.inserts, wardInner(m, secs, i, t)) }
            add("confirmat", 4 * (4 + 2 * (secs.size - 1)))
            if (m.legs) add("leg", 2 * (secs.size + 1))
        }
        else -> {
            fronts(m.fronts, m.w, m.h); inside(m.inserts, m.w - 2 * t)
            add("confirmat", if (m.type == "base") 24 else 16)
            if (m.type == "wall") add("hanger", 2)
            if (m.type != "wall" && m.legs) add("leg", if (m.w > 900) 6 else 4)
        }
    }
    return n
}

/** An order's hardware, all modules added up. */
fun hardware(fs: List<Furniture>, ws: Workshop): Map<String, Int> {
    val n = LinkedHashMap<String, Int>()
    fs.forEach { f -> f.modules.forEach { m -> hardwareOf(m, ws).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v } } }
    return n
}
