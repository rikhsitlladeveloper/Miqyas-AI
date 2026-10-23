package uz.metrx.app.furniture

import java.math.BigInteger
import java.math.RoundingMode

/*
 * What an order costs the workshop (furniture plan section 6.7): sheets to buy (from the sheet layout), banding by the
 * metre, hardware, and labour. Money is whole numbers of the smallest unit; nothing is rounded but the metres of
 * banding and rail, which are bought whole (up).
 */

/** One cost line: [group] mat, hw or lab; [key] a material or hardware id, or a labour strings key; [qty] how many of [unit]. */
data class CostLine(val group: String, val key: String, val qty: Double, val unit: String, val price: BigInteger, val amount: BigInteger, val missing: Boolean)

data class Cost(val lines: List<CostLine>, val layouts: List<Layout>, val rows: List<CutRow>) {
    fun sum(g: String): BigInteger = lines.filter { it.group == g }.fold(BigInteger.ZERO) { a, l -> a + l.amount }
    val total: BigInteger get() = lines.fold(BigInteger.ZERO) { a, l -> a + l.amount }
    /** Lines that have no price yet in the workshop's lists. */
    val missing: Int get() = lines.count { it.missing }
}

private fun money(s: String?): BigInteger? = s?.trim()?.takeIf { it.isNotEmpty() }?.toBigIntegerOrNull()

/** Whole metres for [mm] millimetres, rounded up. */
private fun metres(mm: Double) = Math.ceil(mm - 1e-9)

/**
 * The cost of [fs] with this workshop's settings and lists. [order] adds installation and delivery once (an order with
 * furniture in it). The store's remnants [rems] are cut first: only the new sheets are bought.
 */
fun costOf(fs: List<Furniture>, ws: Workshop, mats: List<Mat>, hws: List<Hw>, order: Boolean = true, rems: List<Remnant> = emptyList()): Cost {
    val rows = cutList(fs, ws)
    val lays = layouts(rows, mats, ws, rems)
    val lines = ArrayList<CostLine>()
    fun mat(id: String) = mats.firstOrNull { it.id == id }
    lays.forEach { l ->
        val p = money(mat(l.mat)?.price)
        // a part longer than the sheet is not left out of the price: a sheet of its own each (bought longer or joined)
        val n = l.sheets.size + l.unplaced.size
        lines += CostLine("mat", l.mat, n.toDouble(), "sheet", p ?: BigInteger.ZERO, (p ?: BigInteger.ZERO) * BigInteger.valueOf(n.toLong()), p == null)
    }
    // kitchens: the worktop as one simple item by the running metre (plan section 7; joints and cut-outs in Stage 1b)
    val wtMm = fs.filter { it.kind == "kitchen" }.sumOf { f -> worktopRuns(f).values.sum() } +
        // a table's or bar counter's top of worktop board
        fs.sumOf { f -> f.modules.sumOf { itemWorktopMm(it) } }
    if (wtMm > 0) {
        val p = money(mat("wt38")?.price)
        lines += CostLine("mat", "wt38", wtMm / 1000.0, "m", p ?: BigInteger.ZERO,
            java.math.BigDecimal(p ?: BigInteger.ZERO).multiply(java.math.BigDecimal(wtMm)).divide(java.math.BigDecimal(1000), 0, RoundingMode.HALF_UP).toBigInteger(), p == null)
    }
    // the backsplash panel, by the running metre like the worktop
    val spMm = fs.filter { it.kind == "kitchen" && (it.kx?.splash ?: 0) > 0 }.sumOf { splashMm(it) }
    if (spMm > 0) {
        val sp = mats.firstOrNull { it.kind == "splash" }
        val p = money(sp?.price)
        lines += CostLine("mat", sp?.id ?: "splash6", spMm / 1000.0, "m", p ?: BigInteger.ZERO,
            java.math.BigDecimal(p ?: BigInteger.ZERO).multiply(java.math.BigDecimal(spMm)).divide(java.math.BigDecimal(1000), 0, RoundingMode.HALF_UP).toBigInteger(), p == null)
    }
    val (thick, thin) = bandMetres(rows)
    listOf("band2" to thick, "band04" to thin).filter { it.second > 0 }.forEach { (id, m) ->
        val q = metres(m); val p = money(mat(id)?.price)
        lines += CostLine("mat", id, q, "m", p ?: BigInteger.ZERO, (p ?: BigInteger.ZERO) * BigInteger.valueOf(q.toLong()), p == null)
    }
    // handles of a kind chosen for a piece ("Change for all") are priced at that item, the rest at the usual one
    val counts = LinkedHashMap<Pair<String, Hw?>, Int>()
    hardware(fs, ws).forEach { (k, v) -> counts[k to usualHw(hws, k)] = v }
    fs.forEach { f ->
        val own = hws.firstOrNull { it.id == f.handle && it.kind == "handle" } ?: return@forEach
        val usual = "handle" to usualHw(hws, "handle")
        val n = minOf(hardware(listOf(f), ws)["handle"] ?: 0, counts[usual] ?: 0)
        if (n <= 0 || own == usual.second) return@forEach
        counts[usual] = (counts[usual] ?: 0) - n
        counts["handle" to own] = (counts["handle" to own] ?: 0) + n
    }
    counts.filter { it.value > 0 }.forEach { (kh, v) ->
        val (k, hw) = kh
        val p = money(hw?.price)
        // rails and profiles by the whole metre, mirror and glass by the m² (to 0,01), the rest by the piece
        val area = k in AREA_KINDS
        val q = when { k in METRE_KINDS -> metres(v / 1000.0); area -> Math.ceil(v / 10000.0 - 1e-9) / 100.0; else -> v.toDouble() }
        val amount = if (area) java.math.BigDecimal(p ?: BigInteger.ZERO).multiply(java.math.BigDecimal.valueOf(q)).setScale(0, RoundingMode.HALF_UP).toBigInteger()
            else (p ?: BigInteger.ZERO) * java.math.BigDecimal(q).setScale(0, RoundingMode.UP).toBigInteger()
        lines += CostLine("hw", hw?.id ?: k, q, when { k in METRE_KINDS -> "m"; area -> "m2"; else -> "pcs" }, p ?: BigInteger.ZERO, amount, p == null)
    }
    // cutting a remnant is as much work as a sheet
    val sheets = lays.sumOf { it.sheets.size + it.unplaced.size + it.rems.size }
    val modules = fs.sumOf { f -> f.modules.sumOf { m -> if (m.type == "wardrobe") maxOf(1, m.sections.size) else 1 } }
    fun lab(key: String, q: Double, unit: String, rate: String) {
        val r = money(rate) ?: BigInteger.ZERO
        if (q > 0) lines += CostLine("lab", key, q, unit, r, r * BigInteger.valueOf(Math.round(q)), false)
    }
    lab("fc.cut", sheets.toDouble(), "sheet", ws.rCut)
    lab("fc.band", metres(thick + thin), "m", ws.rBand)
    lab("fc.asm", modules.toDouble(), "module", ws.rAsm)
    if (order && fs.any { it.modules.isNotEmpty() }) { lab("fc.install", 1.0, "order", ws.rInstall); lab("fc.deliver", 1.0, "order", ws.rDeliver) }
    return Cost(lines, lays, rows)
}

/**
 * The item a hardware kind is priced at: the last of the kind (the workshop's own item added after the preset takes
 * over), but not one of the extra handle kinds offered for "Change for all".
 */
fun usualHw(hws: List<Hw>, kind: String): Hw? = hws.lastOrNull { it.kind == kind && it.id !in HANDLE_MORE }

/** The customer price from the cost with the workshop's margin, rounded half up. */
fun withMargin(cost: BigInteger, pct: Int): BigInteger =
    java.math.BigDecimal(cost).multiply(java.math.BigDecimal(100 + pct)).divide(java.math.BigDecimal(100), 0, RoundingMode.HALF_UP).toBigInteger()
