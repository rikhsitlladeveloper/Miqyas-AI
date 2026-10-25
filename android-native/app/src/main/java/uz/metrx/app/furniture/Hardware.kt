package uz.metrx.app.furniture

/*
 * Hardware counting (furniture plan section 6.6). Keys are [Hw.kind]s; "rail" is counted in millimetres of rail.
 * Every rule is a default for the founder's furniture makers to check.
 */

/** Kinds counted in millimetres and bought by the metre. */
val METRE_KINDS = setOf("rail", "slideTrack", "slideV", "slideH", "cornice", "led", "plinthK", "barRail", "gola", "ceilUnit", "wdCeil")
/** Kinds counted in square millimetres and bought by the m². */
val AREA_KINDS = setOf("mirror", "glass", "glassShelf", "glassDoor", "frontShaker", "frontFluted", "fglass", "mirrorBronze", "mirrorGraphite",
    "headSoft", "headTufted", "softPanel", "tvStone", "tvSlats", "tvMould")

/** How a kind is bought: "m", "m2" or "pcs" (the strings key fu.*). */
fun hwUnit(kind: String) = when (kind) { in METRE_KINDS -> "m"; in AREA_KINDS -> "m2"; else -> "pcs" }

/** A counted amount as people read it: millimetres as metres, square millimetres as m². */
fun hwAmount(kind: String, v: Int, en: Boolean): String = when (kind) {
    in METRE_KINDS -> String.format(java.util.Locale.ROOT, "%.2f m", v / 1000.0)
    in AREA_KINDS -> String.format(java.util.Locale.ROOT, "%.2f m²", v / 1e6)
    else -> "$v"
}.let { if (en) it else it.replace('.', ',') }

/** [m]'s hardware; [edge]: its piece opens by its edge ([opensByEdge]), a front without a handle takes no push latch. */
fun hardwareOf(m: Module, ws: Workshop, edge: Boolean = false): Map<String, Int> {
    val n = HashMap<String, Int>()
    fun add(k: String, v: Int) { if (v > 0) n[k] = (n[k] ?: 0) + v }
    // soft close is a section's own choice (a kitchen unit's is the unit's)
    fun hinge(sec: Int) = if (if (sec < 0) m.soft else softOf(m, sec)) "hingeSoft" else "hinge"
    // a front without a handle opens by a push latch (Handles.kt), unless the piece opens by its edge
    fun pull(key: String) { if (hasHandle(m, key)) add("handle", 1) else if (!edge) add("push", 1) }
    fun fronts(f: Fronts, w: Int, h: Int, face: String = "", sec: Int = -1) {
        val fs = frontSizes(f, w, h, ws)
        fun key(j: Int) = if (sec < 0) "f$j" else "s$sec:f$j"
        when (f.kind) {
            "door" -> fs.forEachIndexed { j, (fh, fw) ->
                // a glass door in its frame has no handle: a push latch, as the 3D shows it
                add(hinge(sec), hingesFor(fh)); pull(key(j))
                // a vitrina's glass door in its frame, a mirror glued on a board door
                when (face) { "glass" -> add("glassDoor", fh * fw); "mirror" -> add("mirror", (fh - 10) * (fw - 10)) }
            }
            "drawer" -> { add("runner", fs.size); fs.indices.forEach { pull(key(it)) } }
        }
    }
    fun inside(ins: List<Insert>, iw: Int) {
        ins.forEach { x ->
            when (x.kind) {
                "shelf" -> add("pin", 4 * x.qty)
                "glass" -> { add("pin", 4 * x.qty); add("glassShelf", (iw - 4) * (innerD(m) - 25) * x.qty) }
                "rail" -> { add("rail", iw); add("railEnd", 2) }
                "drawer", "trouser", "shoe" -> add("runner", 1)
                "lift" -> add("lift", 1)
            }
        }
    }
    val t = ws.t
    if (m.type == "filler") return n
    // a kitchen's space for a machine: a dishwasher's front (on the machine's own door) takes a handle or a push latch
    if (m.type == "gap") { handleFronts(m).forEach { pull(it.key) }; return n }
    if (m.type in ITEM_MODS) { itemHardware(m, ws, ::add); return n }
    when (m.type) {
        "wardrobe" -> {
            val secs = m.sections.ifEmpty { listOf(Section(m.w)) }
            secs.forEachIndexed { i, s ->
                if (m.slide == null) fronts(s.fronts, frontW(s), m.h - wardBase(m), s.face, i); inside(s.inserts, wardInner(m, secs, i, t))
                // a section's drawers (an open one's, or behind the doors) are pulled by a handle of their own, or pushed open
                handleFronts(m).filter { it.sec == i && it.key.contains(":d") }.forEach { pull(it.key) }
            }
            m.slide?.let { sl ->
                val n2 = sl.n.coerceIn(2, 4)
                val (ow, _) = slideOpening(m, t)
                val (dw, dh) = slideDoor(m, t)
                // a mirror or lacobel filling as the 3D draws it: below the split rail only (the board above it: Parts.kt)
                val (pw, _) = slidePanel(m, t)
                val ph = kupeFillH(m, t).first
                add("slideTrack", 2 * ow)            // the top and the bottom track
                add("slideV", 2 * dh * n2)           // two upright profiles a door
                add("slideH", 2 * dw * n2)           // the frame's top and bottom
                add("slideRoller", n2)               // one roller set a door
                (0 until n2).forEach { i -> if (sl.panel(i) != "ldsp") add(sl.panel(i), pw * ph) }
            }
            add("confirmat", 4 * (4 + 2 * (secs.size - 1)))
            if (m.legs) add("leg", 2 * (secs.size + 1))
            // a hung cabinet (or one standing on another) is held by two hangers
            else if (m.elev > 0) add("hanger", 2)
            if (m.led) { add("led", m.w - 2 * t); add("ledPsu", 1) }
        }
        else -> {
            // a kitchen vitrina's glass doors in their frames, by the m² (their hinges and handles as any door's)
            fronts(m.fronts, m.w, m.h, if (glassDoors(m)) "glass" else ""); inside(m.inserts, m.w - 2 * t)
            add("confirmat", if (m.type == "base") 24 else 16)
            if (m.type == "wall") add("hanger", 2)
            if (m.type != "wall" && m.legs) add("leg", if (m.w > 900) 6 else 4)
        }
    }
    return n
}

/** An order's hardware, all modules added up; a piece's design changes and adds to it (Look.kt). */
fun hardware(fs: List<Furniture>, ws: Workshop): Map<String, Int> {
    val n = LinkedHashMap<String, Int>()
    fs.forEach { f ->
        f.modules.forEach { m ->
            val h = LinkedHashMap(hardwareOf(m, wsOf(f, ws), opensByEdge(f)))
            lookSwap(f, m, h, opensByEdge(f))
            h.forEach { (k, v) -> n[k] = (n[k] ?: 0) + v }
        }
        extrasHardware(f).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v }
        lookHardware(f, ws).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v }
        // a gorka's LED strips and cornice (Gorka.kt)
        gorkaHardware(f, ws).forEach { (k, v) -> n[k] = (n[k] ?: 0) + v }
    }
    return n
}
