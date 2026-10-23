package uz.metrx.app.furniture

/*
 * The order's one "Check" list before the design is sent (bazis ideas, 23 Oct 2026): every piece's problems in one
 * place, each tappable to open its piece. The board rules are here; what needs the room (fit on the walls, doors that
 * hit, the designers' own checks) comes in from the screen. Pure Kotlin, unit-tested (BazisTest).
 */

/** One problem of the order: piece [fid]; [level] err or warn; [key] its text with [vars]; [mid] the module, if one. */
data class OrderIssue(val fid: String, val level: String, val key: String, val vars: Map<String, Any> = emptyMap(), val mid: String? = null)

/**
 * The longest shelf a board of [t] mm carries without bending, mm, when nothing holds it in the middle: 1000 for 16 mm
 * board (the wardrobe designer's own rule), 1100 for 18 mm and thicker.
 */
fun shelfSpanMax(t: Int) = if (t >= 18) 1100 else 1000

/** A shelf in a section [iw] mm wide inside (the shelf is 2 mm shorter) bends on board of [t] mm: the designer's and the Check list's one rule. */
fun shelfTooLong(iw: Int, t: Int) = iw - 2 > shelfSpanMax(t)

/** The board rules of one piece: a part bigger than the sheet, a drawer deeper than its box, a shelf too long to carry. */
fun boardIssues(f: Furniture, ws0: Workshop, mats: List<Mat>): List<OrderIssue> {
    val ws = wsOf(f, ws0)
    val out = ArrayList<OrderIssue>()
    // a part that fits no sheet of its material (the price counts a sheet of its own for it)
    val rows = cutList(listOf(f), ws)
    layouts(rows, mats, ws).forEach { l ->
        l.unplaced.distinct().forEach { i ->
            val r = rows[i]
            out += OrderIssue(f.id, "err", "bz.ck.sheet", mapOf("p" to r.p.key, "l" to r.cutL, "w" to r.cutW, "sl" to l.sheetL - 2 * ws.trim, "sw" to l.sheetW - 2 * ws.trim))
        }
    }
    val t = ws.t
    val span = shelfSpanMax(t)
    f.modules.forEach { m ->
        when (m.type) {
            "wardrobe" -> {
                val dIn = innerD(m)
                m.sections.forEachIndexed { i, s ->
                    if (s.knee) return@forEachIndexed
                    val iw = wardInner(m, m.sections, i, t)
                    if (s.inserts.any { it.kind == "drawer" } && runnerLen(dIn) > dIn - 10)
                        out += OrderIssue(f.id, "err", "bz.ck.drawer", mapOf("s" to i + 1, "r" to runnerLen(dIn), "v" to dIn), m.id)
                    if (s.inserts.any { it.kind == "shelf" } && shelfTooLong(iw, t))
                        out += OrderIssue(f.id, "warn", "bz.ck.shelf", mapOf("s" to i + 1, "v" to iw - 2, "t" to t, "max" to span), m.id)
                }
            }
            "base", "wall", "tall" -> {
                if (m.fronts.kind == "drawer" && runnerLen(m.d) > m.d - 10)
                    out += OrderIssue(f.id, "err", "bz.ck.drawer", mapOf("s" to 1, "r" to runnerLen(m.d), "v" to m.d), m.id)
                if (m.inserts.any { it.kind == "shelf" } && m.w - 2 * t - 2 > span)
                    out += OrderIssue(f.id, "warn", "bz.ck.shelf", mapOf("s" to 1, "v" to m.w - 2 * t - 2, "t" to t, "max" to span), m.id)
            }
        }
    }
    return out
}

/**
 * Every problem of the order's pieces [fs], errors first: the board rules and what [extra] adds for a piece (its fit
 * on its walls, doors that hit, its designer's checks). A problem said twice is said once.
 */
fun orderChecks(fs: List<Furniture>, ws: Workshop, mats: List<Mat>, extra: (Furniture) -> List<OrderIssue> = { emptyList() }): List<OrderIssue> =
    fs.filter { it.modules.isNotEmpty() }.flatMap { f -> (boardIssues(f, ws, mats) + extra(f)).distinct() }
        .sortedBy { if (it.level == "err") 0 else 1 }
