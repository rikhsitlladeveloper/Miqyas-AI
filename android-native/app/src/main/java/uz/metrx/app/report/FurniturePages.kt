package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.style.TextAlign
import uz.metrx.app.data.Snap
import uz.metrx.app.data.dn
import uz.metrx.app.data.fmtDate
import uz.metrx.app.furniture.CutRow
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Hw
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Layout
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Priced
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.costOf
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.kindOf
import uz.metrx.app.furniture.outerH
import uz.metrx.app.furniture.runMm
import uz.metrx.app.ui.furniture.frontFigures
import java.math.BigDecimal
import java.math.BigInteger
import java.math.RoundingMode
import kotlin.math.max
import kotlin.math.min

/*
 * Furniture orders' documents (furniture plan section 10), on the report's A4 pages: the customer's quote (3D views,
 * materials and colours, the price and terms, the front drawings; never the cost, cut list or profit) and the
 * workshop pack (sheets, cut list, sheet layouts, hardware, modules, cost and profit).
 */

private val F_INK = Color(0xFF0E1C36)
private val F_INK3 = Color(0xFF3E4A61)
private val F_RULE = Color(0xFF9AA8BF)
private val F_FIG = Color(0xFFC3CEDF)
private val SHEET_BG = Color(0xFFF3F6FA)
private val PART_BG = Color(0xFFDDE6F5)

private fun hexColor(s: String) = runCatching { Color(android.graphics.Color.parseColor(s)) }.getOrDefault(Color(0xFFF5F5F2))

private fun Doc.metres(mm: Int): String {
    val v = (mm + 50) / 100
    return "${v / 10}${if (en) "." else ","}${v % 10}"
}

/** "Oshxona 1 (L, 5,4 pog. m): korpus, fasadlar, stoleshnitsa, furnitura" or "Shkaf 1 (2400 × 2500, 4 bo‘lim, 7 eshik)". */
private fun Doc.pieceText(f: Furniture, ws: Workshop?): String {
    val name = dn(f.name, l)
    return if (f.kind == "wardrobe") {
        val m = f.modules.firstOrNull { it.type == "wardrobe" } ?: return name
        val doors = m.sections.sumOf { if (it.fronts.kind == "door") it.fronts.n else 0 }
        t("fd.lineW", "n" to name, "w" to m.w, "h" to (ws?.let { outerH(m, it) } ?: m.h), "s" to m.sections.size, "d" to doors)
    } else t("fd.lineK", "n" to name, "l" to t("kt.l" + f.layout), "v" to metres(runMm(f)))
}

private fun Doc.figure(title: String, vw: Float, vh: Float, draw: androidx.compose.ui.graphics.drawscope.DrawScope.() -> Unit) {
    // two figures a page: at most 300 high, centred
    val fw = min(CW, 300f * vw / vh); val h = fw * vh / vw; val fx = PX + (CW - fw) / 2
    val cap = measure(title, ui(10f, 600), CW)
    space(10f)
    if (y + cap.size.height + 4f + h > LIMIT) { newPage(); space(10f) }
    val top = y
    draw {
        drawText(cap, topLeft = Offset(PX, top))
        val ft = top + cap.size.height + 4f
        drawRect(Color.White, Offset(fx, ft), Size(fw, h))
        clipRect(fx, ft, fx + fw, ft + h) { translate(fx, ft) { scale(fw / vw, fw / vw, Offset.Zero) { draw() } } }
        drawRect(F_FIG, Offset(fx + .375f, ft + .375f), Size(fw - .75f, h - .75f), style = Stroke(.75f))
    }
    y += cap.size.height + 4f + h; after(10f)
}

/* ---------------- the customer's quote ---------------- */

fun furniturePages(tm: TextMeasurer, sn: Snap, draft: Boolean, meta: QuoteMeta?, image: (String) -> ImageBitmap?, now: Long = System.currentTimeMillis(),
                   prices: Boolean = true): List<RPage> {
    // without prices (the simple app) it is the design: dated, no draft mark, no price block
    val d = Doc(tm, sn, draft && prices, meta, image, now)
    d.draftTitle = "fd.draft"; d.quoteTitle = if (prices) "fd.quote" else "rpt.design"; d.makerKey = "fd.maker"
    if (!prices) d.subLine = uz.metrx.app.data.fmtDate(now)
    d.newPage(); d.parties()
    if (sn.pdf.views) d.views()
    d.materials(sn)
    if (prices) d.priceBlock(sn)
    // the front drawings, one per wall or wardrobe
    val ws = sn.fws ?: Workshop()
    val figs = sn.furniture.flatMap { f ->
        val room = if (f.roomId == null) uz.metrx.app.furniture.freeRoom(f) else sn.rooms.firstOrNull { it.room.id == f.roomId }?.room
        frontFigures(f, room, ws, sn.fmats).map { f to it }
    }
    if (figs.isNotEmpty()) {
        d.newPage(); d.h2(d.t("fd.fronts"))
        figs.forEach { (f, fig) ->
            val tmm = tm
            val title = dn(f.name, d.l) + when (fig.wall) { null -> ""; ISLAND -> " · " + d.t(if (f.layout == "P") "kt.peninsula" else "kt.island")
                else -> " · " + if (f.roomId == null) d.t("fz.sideN", "n" to f.walls.indexOf(fig.wall) + 1) else d.t("kt.wallN", "w" to fig.wall) }
            d.figure(title, fig.vw, fig.vh) { fig.draw(this, tmm) }
        }
        d.fn(d.t("fd.frontNote"))
    }
    return d.finish()
}

/** Carcass, fronts, worktop and handles as colour swatches with their names. */
private fun Doc.materials(sn: Snap) {
    val entries = ArrayList<Triple<String, String, String?>>()   // role label, name, colour
    fun mat(id: String) = sn.fmats.firstOrNull { it.id == id }
    listOf("carcass" to { f: Furniture -> f.mats.carcass }, "front" to { f: Furniture -> f.mats.front }).forEach { (role, get) ->
        val ids = sn.furniture.map(get).distinct()
        ids.forEach { id ->
            val who = if (ids.size > 1) " (" + sn.furniture.filter { get(it) == id }.joinToString { dn(it.name, l) } + ")" else ""
            entries += Triple(t("wd.$role") + who, mat(id)?.name ?: id, mat(id)?.rgb)
        }
    }
    if (sn.furniture.any { it.kind == "kitchen" }) mat("wt38")?.let { entries += Triple(t("mt.wtK"), it.name, it.rgb) }
    if (sn.furniture.any { (it.kx?.splash ?: 0) > 0 }) mat("splash6")?.let { entries += Triple(t("mt.splashK"), it.name, it.rgb) }
    if (sn.fhandles.isNotBlank() && sn.furniture.any { f -> f.modules.any { it.handles } }) entries += Triple(t("hk.handle"), sn.fhandles, null)
    if (entries.isEmpty()) return
    h2(t("fd.mats"))
    // the swatch in a narrow first column
    val rows = entries.map { (role, name, _) -> listOf(cell(""), cell(role, ui(10f, 600)), cell(dn(name, l))) }
    space(6f)
    val top = y
    table(rows, fixed = floatArrayOf(28f, (CW - 28f) * .42f, (CW - 28f) * .58f), breakable = false, top = 0f)
    var yy = top
    val rowH = measure(AnnotatedString(" "), ui(10f)).size.height + 6f
    entries.forEach { (_, _, rgb) ->
        val at = yy
        if (rgb != null) draw {
            drawRect(hexColor(rgb), Offset(PX + 6f, at + (rowH - 11f) / 2f), Size(16f, 11f))
            drawRect(F_RULE, Offset(PX + 6f, at + (rowH - 11f) / 2f), Size(16f, 11f), style = Stroke(.75f))
        }
        yy += rowH
    }
}

/** The price: a line a piece of furniture, delivery and installation, the total, the prepayment, the rest and the time. */
private fun Doc.priceBlock(sn: Snap) {
    // the price stays on one page with its total and terms
    ensure(40f + (max(sn.flines.size, sn.furniture.size) + 5) * 17f + 50f)
    h2(t("fd.price"))
    val total = sn.ftotal.toBigIntegerOrNull() ?: BigInteger.ZERO
    val rows = ArrayList<List<Cell>>()
    if (sn.flines.isEmpty()) sn.furniture.forEach { f -> rows += listOf(cell(pieceText(f, sn.fws), span = 2)) }
    sn.flines.forEach { ln ->
        val f = sn.furniture.firstOrNull { it.id == ln.key }
        val text = if (ln.key == "deliver") t("fd.deliver") else f?.let { pieceText(it, sn.fws) } ?: ln.key
        rows += listOf(cell(text), rcell(money(ln.amount.toBigIntegerOrNull() ?: BigInteger.ZERO)))
    }
    table(rows, fixed = floatArrayOf(CW * .72f, CW * .28f))
    fn(t("fd.priceNote"))
    ensure(90f)
    val pre = BigDecimal(total).multiply(BigDecimal(sn.fprepay)).divide(BigDecimal(100), 0, RoundingMode.HALF_UP).toBigInteger()
    val cur = uz.metrx.app.core.curSuffix(sn.currency, l)
    table(listOf(
        listOf(cell(t("fd.total"), ui(11f, 700)), Cell(listOf(AnnotatedString(money(total) + " " + cur) to num(11f, 700)), right = true, dbl = true)),
        listOf(cell(t("fd.prepay", "p" to sn.fprepay)), rcell(money(pre))),
        listOf(cell(t("fd.onInstall")), rcell(money(total - pre))),
        listOf(cell(t("fd.time")), rcell(t("fd.days", "d" to sn.fdays, "i" to sn.finst), ui(10f, 600, align = TextAlign.End)))
    ), fixed = floatArrayOf(CW * .6f, CW * .4f), breakable = false)
    fn(t("fd.valid"))
}

/* ---------------- the workshop pack ---------------- */

/** Readable labels for the modules: each wall's units A1, A2… (lower row first), the island O1…, wardrobes Sh1. */
fun labelled(fs: List<Furniture>): List<Furniture> {
    var ward = 0
    return fs.map { f ->
        if (f.kind == "wardrobe") f.copy(modules = f.modules.map { m -> ward++; m.copy(label = "Sh$ward") })
        else {
            val n = HashMap<String, Int>()
            val order = f.modules.sortedBy { if (isUpper(it)) 1 else 0 }.map { it.id }
            val labels = HashMap<String, String>()
            order.forEach { id ->
                val m = f.modules.first { it.id == id }
                val w = if (m.wall == ISLAND) "O" else m.wall ?: "?"
                val k = (n[w] ?: 0) + 1; n[w] = k; labels[id] = "$w$k"
            }
            f.copy(modules = f.modules.map { it.copy(label = labels[it.id] ?: it.label) })
        }
    }
}

private fun Doc.bandText(r: CutRow): String {
    val b = r.p.bands
    val thick = listOf(b.l1, b.l2, b.s1, b.s2).count { it == 2 }; val thin = listOf(b.l1, b.l2, b.s1, b.s2).count { it == 1 }
    return listOfNotNull(if (thick > 0) "2 mm × $thick" else null, if (thin > 0) (if (en) "0.4" else "0,4") + " × $thin" else null).joinToString(", ").ifEmpty { "—" }
}

/** The pack: summary, cut list a material, the sheets, hardware, modules, cost and profit. Not for the customer. */
fun workshopPages(tm: TextMeasurer, sn: Snap, ws: Workshop, mats: List<Mat>, hws: List<Hw>, pr: Priced, mode: String, now: Long = System.currentTimeMillis()): List<RPage> {
    val d = Doc(tm, sn, false, null, { null }, now)
    d.quoteTitle = "fw.title"
    d.subLine = d.t("fw.sub", "d" to fmtDate(now))
    val fs = labelled(sn.furniture)
    val cost = costOf(fs, ws, mats, hws)
    fun matName(id: String) = mats.firstOrNull { it.id == id }?.name ?: id
    d.newPage()
    d.para(AnnotatedString(dn(sn.name, d.l) + " · " + fs.joinToString(" + ") { dn(it.name, d.l) }), d.ui(11f, 600), 0f, 4f)
    d.para(AnnotatedString(d.t("fw.inside")), d.ui(9f, 700, F_INK3), 0f, 8f)
    // 1. what to buy
    d.h2(d.t("fw.summary"))
    val sum = ArrayList<List<Cell>>()
    sum += listOf(d.th(d.t("fw.c.mat")), d.th(d.t("fw.c.sheets"), true), d.th(d.t("fw.c.parts"), true), d.th(d.t("fw.c.waste"), true))
    cost.layouts.forEach { lay ->
        val parts = cost.rows.filter { it.mat == lay.mat }.sumOf { it.p.qty }
        sum += listOf(d.cell(dn(matName(lay.mat), d.l)), d.rcell("${lay.sheets.size}"), d.rcell("$parts"), d.rcell("${(lay.waste * 100).toInt()} %"))
    }
    cost.lines.filter { it.group == "mat" && (it.unit == "m") }.forEach { ln ->
        sum += listOf(d.cell(dn(matName(ln.key), d.l)), d.rcell(fmtQty(d, ln.qty) + " m"), d.cell(""), d.cell(""))
    }
    d.table(sum, head = 1)
    cost.layouts.filter { it.unplaced.isNotEmpty() }.forEach { lay -> d.fn(d.t("fw.unplaced", "m" to matName(lay.mat), "n" to lay.unplaced.size)) }
    // 2. the cut list, a material at a time
    val byMat = cost.rows.withIndex().groupBy { it.value.mat }
    val number = HashMap<Int, Int>()
    byMat.forEach { (_, list) -> list.forEachIndexed { k, iv -> number[iv.index] = k + 1 } }
    byMat.forEach { (mat, list) ->
        d.h2(d.t("fw.cut", "m" to dn(matName(mat), d.l), "n" to list.sumOf { it.value.p.qty }))
        val rows = ArrayList<List<Cell>>()
        rows += listOf(d.th("№"), d.th(d.t("fw.c.part")), d.th(d.t("fw.c.size"), true), d.th(d.t("fw.c.cut"), true), d.th(d.t("fw.c.qty"), true), d.th(d.t("fw.c.band")))
        list.forEach { (i, r) ->
            rows += listOf(d.cell("${number[i]}"), d.cell(d.t(r.p.key) + if (r.p.grain) " ↕" else ""), d.rcell("${r.p.L} × ${r.p.W}"), d.rcell("${r.cutL} × ${r.cutW}"),
                d.rcell("${r.p.qty}"), d.cell(d.bandText(r), d.num(9.5f)))
        }
        d.table(rows, head = 1)
    }
    d.fn(d.t("fw.cutNote", "b" to (if (d.en) "${ws.band10 / 10}.${ws.band10 % 10}" else "${ws.band10 / 10},${ws.band10 % 10}")))
    // 3. the sheets
    cost.layouts.forEach { lay -> d.sheets(lay, number, matName(lay.mat), ws) }
    // 4. hardware
    d.newPage(); d.h2(d.t("fw.hw"))
    val hr = ArrayList<List<Cell>>()
    hr += listOf(d.th(d.t("fw.c.name")), d.th(d.t("fw.c.qty"), true), d.th(d.t("fw.c.price"), true), d.th(d.t("fw.c.sum"), true))
    cost.lines.filter { it.group == "hw" }.forEach { ln ->
        val hw = hws.firstOrNull { it.id == ln.key }
        hr += listOf(d.cell(hw?.name ?: d.t("hk.${ln.key}")), d.rcell(fmtQty(d, ln.qty) + (when (ln.unit) { "m" -> " m"; "m2" -> " m²"; else -> "" })),
            d.rcell(if (ln.missing) "—" else d.money(ln.price)), d.rcell(d.money(ln.amount)))
    }
    hr += listOf(d.cell(d.t("r.total"), d.ui(10f, 700), span = 3), d.rcell(d.money(cost.sum("hw")), d.num(10f, 700)))
    d.table(hr, head = 1)
    // 5. the modules and their sizes
    d.h2(d.t("fw.mods"))
    val mr = ArrayList<List<Cell>>()
    mr += listOf(d.th("№"), d.th(d.t("fw.c.name")), d.th(d.t("fw.c.wxhxd"), true), d.th(d.t("fw.c.fronts")))
    fs.forEach { f -> f.modules.forEach { m -> mr += listOf(d.cell(m.label), d.cell(d.modText(m)), d.rcell("${m.w} × ${m.h} × ${m.d}"), d.cell(d.frontText(m))) } }
    d.table(mr, head = 1)
    // 6. cost, price, profit
    d.ensure(140f); d.h2(d.t("fw.cost"))
    val cr = ArrayList<List<Cell>>()
    listOf("mat" to "fw.g.mat", "hw" to "fw.g.hw", "lab" to "fw.g.lab").forEach { (g, k) -> cr += listOf(d.cell(d.t(k)), d.rcell(d.money(cost.sum(g)))) }
    cr += listOf(d.cell(d.t("fw.costT"), d.ui(10f, 700)), d.rcell(d.money(pr.cost.total), d.num(10f, 700)))
    cr += listOf(d.cell(d.t("fw.priceT", "m" to d.t("fpm.$mode"))), d.rcell(d.money(pr.price), d.num(10f, 700)))
    val pct = pr.profitPct10
    cr += listOf(d.cell(d.t("fw.profit")), d.rcell(d.money(pr.profit) + " · " + "${pct / 10}${if (d.en) "." else ","}${kotlin.math.abs(pct % 10)} %", d.num(10f, 700)))
    d.table(cr, fixed = floatArrayOf(CW * .6f, CW * .4f), breakable = false)
    if (cost.missing > 0) d.fn(d.t("kt.noPrice", "n" to cost.missing))
    return d.finish()
}

private fun fmtQty(d: Doc, q: Double): String =
    if (q == Math.floor(q)) "${q.toLong()}" else String.format(java.util.Locale.ROOT, "%.1f", q).let { if (d.en) it else it.replace('.', ',') }

private fun Doc.modText(m: Module) = if (m.type == "wardrobe") t("kn.wardrobe") else t("kn." + kindOf(m))

private fun Doc.frontText(m: Module): String = when {
    m.type == "wardrobe" -> t("fw.secs", "n" to m.sections.size, "d" to m.sections.sumOf { if (it.fronts.kind == "door") it.fronts.n else 0 })
    m.fronts.kind == "door" -> t(if (m.fronts.n >= 2) "km.f2" else "km.f1")
    m.fronts.kind == "drawer" -> t("km.fd") + " " + m.fronts.n
    m.fronts.kind == "panel" -> t("fp.panel")
    else -> "—"
}

/** Two sheets a page: the trimmed area, the parts with their cut list numbers. */
private fun Doc.sheets(lay: Layout, number: Map<Int, Int>, name: String, ws: Workshop) {
    lay.sheets.forEachIndexed { i, s ->
        // small enough for two sheets a page
        val w = min(CW, 296f * lay.sheetL / lay.sheetW); val k = w / lay.sheetL; val h = lay.sheetW * k
        val cap = measure(t("fw.sheet", "m" to dn(name, l), "i" to i + 1, "n" to lay.sheets.size, "w" to (lay.waste * 100).toInt()), ui(10f, 600), CW)
        space(10f)
        if (y + cap.size.height + 4f + h + 14f > LIMIT) { newPage(); space(10f) }
        val top = y + cap.size.height + 4f
        val labels = s.placed.map { pl -> pl to measure("${number[pl.row] ?: "?"}", num(max(6f, min(11f, min(pl.w, pl.h) * k * .45f)), 700)) }
        val note = measure(t("fw.sheetNote", "l" to lay.sheetL, "w" to lay.sheetW, "k" to ws.kerf, "t" to ws.trim), ui(8.5f, 400, F_INK3), CW)
        val tr = ws.trim * k
        draw {
            drawText(cap, topLeft = Offset(PX, top - cap.size.height - 4f))
            drawRect(SHEET_BG, Offset(PX, top), Size(w, h)); drawRect(F_INK, Offset(PX, top), Size(w, h), style = Stroke(1f))
            labels.forEach { (pl, lr) ->
                val x = PX + tr + pl.x * k; val yy = top + tr + pl.y * k; val pw = pl.w * k; val ph = pl.h * k
                drawRect(PART_BG, Offset(x, yy), Size(pw, ph)); drawRect(F_INK3, Offset(x, yy), Size(pw, ph), style = Stroke(.6f))
                if (lr.size.width < pw - 2 && lr.size.height < ph - 1) drawText(lr, topLeft = Offset(x + (pw - lr.size.width) / 2f, yy + (ph - lr.size.height) / 2f))
            }
            drawText(note, topLeft = Offset(PX, top + h + 3f))
        }
        y = top + h + 3f + note.size.height; after(8f)
    }
}
