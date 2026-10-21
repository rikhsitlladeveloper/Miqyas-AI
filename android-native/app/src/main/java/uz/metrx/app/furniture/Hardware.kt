package uz.metrx.app.furniture

/*
 * Hardware counting (furniture plan section 6.6). Keys are [Hw.kind]s; "rail" is counted in millimetres of rail.
 * Every rule is a default for the founder's furniture makers to check.
 */

/** Kinds counted in millimetres and bought by the metre. */
val METRE_KINDS = setOf("rail", "slideTrack", "slideV", "slideH", "cornice", "led", "plinthK")
/** Kinds counted in square millimetres and bought by the m². */
val AREA_KINDS = setOf("mirror", "glass")

/** How a kind is bought: "m", "m2" or "pcs" (the strings key fu.*). */
fun hwUnit(kind: String) = when (kind) { in METRE_KINDS -> "m"; in AREA_KINDS -> "m2"; else -> "pcs" }

/** A counted amount as people read it: millimetres as metres, square millimetres as m². */
fun hwAmount(kind: String, v: Int, en: Boolean): String = when (kind) {
    in METRE_KINDS -> String.format(java.util.Locale.ROOT, "%.2f m", v / 1000.0)
    in AREA_KINDS -> String.format(java.util.Locale.ROOT, "%.2f m²", v / 1e6)
    else -> "$v"
}.let { if (en) it else it.replace('.', ',') }

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
            secs.forEachIndexed { i, s ->
                if (m.slide == null) fronts(s.fronts, s.w, m.h - wardBase(m)); inside(s.inserts, wardInner(m, secs, i, t))
                // drawers in an open section are pulled by a handle of their own
                if (s.fronts.kind == "open" && m.handles) add("handle", s.inserts.count { it.kind == "drawer" })
            }
            m.slide?.let { sl ->
                val n2 = sl.n.coerceIn(2, 4)
                val (ow, _) = slideOpening(m, t)
                val (dw, dh) = slideDoor(m, t)
                val (pw, ph) = slidePanel(m, t)
                add("slideTrack", 2 * ow)            // the top and the bottom track
                add("slideV", 2 * dh * n2)           // two upright profiles a door
                add("slideH", 2 * dw * n2)           // the frame's top and bottom
                add("slideRoller", n2)               // one roller set a door
                (0 until n2).forEach { i -> if (sl.panel(i) != "ldsp") add(sl.panel(i), pw * ph) }
            }
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
    fs.forEach { f ->
        f.modules.forEach { m -> hardwareOf(m, ws).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v } }
        extrasHardware(f).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v }
    }
    return n
}
