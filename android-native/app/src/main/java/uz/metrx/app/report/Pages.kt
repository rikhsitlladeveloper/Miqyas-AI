package uz.metrx.app.report

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Phone
import uz.metrx.app.core.Strings
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.fmtNumStr
import uz.metrx.app.core.lineTotal
import uz.metrx.app.core.moneyStr
import uz.metrx.app.core.parseDec
import uz.metrx.app.core.value
import uz.metrx.app.data.Estimate
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Snap
import uz.metrx.app.data.dn
import uz.metrx.app.data.fmtDate
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.ui.markup.drawMarkup
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.ui.components.drawLogoMark
import uz.metrx.app.ui.editor.drawReportPlan
import uz.metrx.app.ui.editor.reportPlanHeight
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.Manrope
import uz.metrx.app.ui.theme.PlexCond
import java.math.BigInteger
import kotlin.math.max
import kotlin.math.min

/*
 * The report's A4 pages (prototype reportPages0, the .a4 styles and the workspace module's extra pages), drawn with
 * Compose drawing commands in CSS pixels of a 595 × 842 page, so one drawing serves the preview (a bitmap) and the PDF
 * (vector, one point per pixel). Where the prototype would run off the bottom of a page, the content continues on a
 * new page with the same header (and the table's heading row again).
 */

const val PAGE_W = 595f
const val PAGE_H = 842f
internal const val PX = 38f
internal const val PY = 36f
internal const val CW = PAGE_W - 2 * PX
internal const val LIMIT = PAGE_H - PY - 6f

private val INK = Color(0xFF0E1C36)
private val INK3 = Color(0xFF3E4A61)
private val GREY = Color(0xFF5F6B82)
private val RULE = Color(0xFF9AA8BF)
private val TH_BG = Color(0xFFF3F6FA)
private val FIG = Color(0xFFC3CEDF)
private val NOTE_RULE = Color(0xFFDCE4F0)
private val PROV = Color(0xFF9A4D00)
private val LOGO = Color(0xFF374FDD)
private val WMK = Color(0x121C4BD1)
private val NBSP = ' '

/** One page: its drawing in page pixels. */
class RPage(val draw: DrawScope.() -> Unit)

/** For an issued quote: its number and when it was issued. */
data class QuoteMeta(val no: Int, val ts: Long)

internal class Cell(val paras: List<Pair<AnnotatedString, TextStyle>>, val span: Int = 1, val right: Boolean = false, val th: Boolean = false, val dbl: Boolean = false)

internal class Doc(val tm: TextMeasurer, val sn: Snap, val draft: Boolean, val meta: QuoteMeta?, val image: (String) -> ImageBitmap?, val now: Long) {
    val l = Lang.of(sn.lang)
    val en = l == Lang.EN
    val face = if (l.cyrillic) Manrope else Jakarta
    val unit = if (sn.unit == "cm") LenUnit.CM else LenUnit.M
    val pages = ArrayList<ArrayList<DrawScope.() -> Unit>>()
    private var ops = ArrayList<DrawScope.() -> Unit>()
    var y = 0f
    private var pend = 0f

    fun t(k: String, vararg v: Pair<String, Any?>) = Strings.t(k, l, if (v.isEmpty()) null else v.toMap())
    fun mUnit() = t(if (unit == LenUnit.CM) "u.cm" else "u.m")
    fun len(mm: Int?) = fmtLen(mm, unit, en)
    fun money(v: BigInteger) = moneyStr(v, sn.precision, en).replace(' ', NBSP)

    fun ui(size: Float, weight: Int = 400, color: Color = INK, italic: Boolean = false, align: TextAlign = TextAlign.Start) = TextStyle(
        fontFamily = face, fontSize = size.sp, fontWeight = FontWeight(weight), color = color, fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        lineHeight = (size * 1.35f).sp, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
        platformStyle = PlatformTextStyle(includeFontPadding = false), textAlign = align
    )
    fun num(size: Float, weight: Int = 400, align: TextAlign = TextAlign.Start) = ui(size, weight, INK, align = align).copy(fontFamily = PlexCond)

    fun measure(s: AnnotatedString, st: TextStyle, w: Float? = null): TextLayoutResult = tm.measure(s, st, density = Density(1f), constraints = when {
        w == null -> Constraints()
        st.textAlign == TextAlign.End || st.textAlign == TextAlign.Center -> Constraints.fixedWidth(max(1, w.toInt()))   // aligned inside the full width
        else -> Constraints(maxWidth = max(1, w.toInt()))
    })
    fun measure(s: String, st: TextStyle, w: Float? = null) = measure(AnnotatedString(s), st, w)

    fun draw(op: DrawScope.() -> Unit) { ops += op }

    /** Vertical margins collapse as in CSS: the larger of the previous bottom and this top. */
    fun space(top: Float) { y += max(pend, top); pend = 0f }
    fun after(bottom: Float) { pend = bottom }
    fun fits(h: Float) = y + max(pend, 0f) + h <= LIMIT

    /** A new page with the header (prototype .rh): the mark and METRX on the left, title and date on the right. */
    /** Furniture documents: another title for the draft and the issued one, and a line under it instead of the date. */
    var draftTitle = "r.draft"; var quoteTitle = "r.quote"; var subLine: String? = null
    /** Furniture orders name the maker's side "Ustaxona". */
    var makerKey = "rpt.builder"

    fun newPage() {
        ops = ArrayList(); pages += ops
        val title = t(if (draft) draftTitle else quoteTitle)
        val date = subLine ?: if (draft) t("r.draftDate", "d" to fmtDate(now)) else t("r.no", "n" to meta!!.no, "d" to fmtDate(meta.ts))
        val h1 = measure(title, ui(18f, 600)); val sm = measure(date, ui(10f, 400, INK3))
        val wm = measure("METRX", num(14f, 700).copy(letterSpacing = .14.em, lineHeight = 18.2.sp))
        val rh = max(18.2f, h1.size.height + sm.size.height.toFloat())
        draw {
            drawRoundRect(LOGO, Offset(PX, PY), Size(18f, 18f), CornerRadius(18f * 15 / 64))
            drawLogoMark(LOGO, 18f, Offset(PX, PY))
            drawText(wm, topLeft = Offset(PX + 24f, PY + (18f - wm.size.height) / 2f))
            drawText(h1, topLeft = Offset(PX + CW - h1.size.width, PY))
            drawText(sm, topLeft = Offset(PX + CW - sm.size.width, PY + h1.size.height))
            drawLine(INK, Offset(PX, PY + rh + 8f + .75f), Offset(PX + CW, PY + rh + 8f + .75f), 1.5f)
        }
        y = PY + rh + 8f + 1.5f; pend = 12f
    }

    fun ensure(h: Float) { if (!fits(h)) newPage() }

    fun h2(text: String) {
        val r = measure(text, ui(12f, 600), CW)
        space(12f); val top = y; draw { drawText(r, topLeft = Offset(PX, top)) }; y += r.size.height; after(4f)
    }

    fun para(text: AnnotatedString, st: TextStyle, top: Float, bottom: Float, x: Float = PX, w: Float = CW) {
        val r = measure(text, st, w)
        space(top); if (y + r.size.height > LIMIT) { newPage(); space(top) }
        val at = y; draw { drawText(r, topLeft = Offset(x, at)) }; y += r.size.height; after(bottom)
    }
    fun fn(text: String) = para(AnnotatedString(text), ui(8.5f, 400, INK3), 4f, 8.5f)

    /* ---------- tables (border-collapse, 0.75 px rules, cells padded 3 × 5, auto column widths as in a browser) ---------- */

    private fun cellWidth(c: Cell): Pair<Float, Float> {
        var mx = 0f; var mn = 0f
        c.paras.forEach { (s, st) ->
            mx = max(mx, measure(s, st).size.width.toFloat())
            s.text.split(' ', '\n').forEach { w -> if (w.isNotEmpty()) mn = max(mn, measure(w, st).size.width.toFloat()) }
        }
        return mn + 10f to mx + 10f
    }

    private fun widths(rows: List<List<Cell>>, w: Float, fixed: FloatArray?): FloatArray {
        val n = rows.maxOf { r -> r.sumOf { it.span } }
        if (fixed != null) return fixed
        val mn = FloatArray(n); val mx = FloatArray(n)
        rows.forEach { r -> var c = 0; r.forEach { cell -> if (cell.span == 1) { val (a, b) = cellWidth(cell); mn[c] = max(mn[c], a); mx[c] = max(mx[c], b) }; c += cell.span } }
        val sMax = mx.sum(); val sMin = mn.sum()
        return FloatArray(n) { i ->
            when {
                sMax <= w -> if (sMax == 0f) w / n else mx[i] + (w - sMax) * mx[i] / sMax
                sMin >= w -> mn[i]
                else -> mn[i] + (w - sMin) * (mx[i] - mn[i]) / max(1e-3f, sMax - sMin)
            }
        }
    }

    private fun cellHeight(c: Cell, w: Float) = c.paras.sumOf { (s, st) -> measure(s, st, w - 10f).size.height.toDouble() }.toFloat() + 6f

    /** A table at [x] across [w]; rows that would run off the page continue on the next one, after the [head] rows again. */
    fun table(rows: List<List<Cell>>, x: Float = PX, w: Float = CW, fixed: FloatArray? = null, head: Int = 0, top: Float = 6f, bottom: Float = 10f, breakable: Boolean = true): Float {
        val cw = widths(rows, w, fixed)
        val hs = rows.map { r -> var c = 0; r.maxOf { cell -> val cwid = (c until c + cell.span).sumOf { cw[it].toDouble() }.toFloat(); c += cell.span; cellHeight(cell, cwid) } }
        space(top)
        val start = y
        rows.forEachIndexed { i, r ->
            if (breakable && i >= head && y + hs[i] > LIMIT && y > PY + 60f) {
                newPage(); space(top)
                for (k in 0 until head) drawRow(rows[k], hs[k], cw, x)
            }
            drawRow(r, hs[i], cw, x)
        }
        after(bottom)
        return y - start
    }

    private fun drawRow(r: List<Cell>, h: Float, cw: FloatArray, x0: Float) {
        val top = y; var x = x0; var c = 0
        r.forEach { cell ->
            val w = (c until c + cell.span).sumOf { cw[it].toDouble() }.toFloat(); c += cell.span
            val lays = cell.paras.map { (s, st) -> measure(s, st.copy(textAlign = if (cell.right) TextAlign.End else TextAlign.Start), w - 10f) }
            val cx = x
            draw {
                if (cell.th) drawRect(TH_BG, Offset(cx, top), Size(w, h))
                drawRect(RULE, Offset(cx, top), Size(w, h), style = Stroke(.75f))
                var ty = top + 3f
                lays.forEach { lr -> drawText(lr, topLeft = Offset(cx + 5f, ty)); ty += lr.size.height }
                if (cell.dbl) { drawLine(INK, Offset(cx, top + h - .5f), Offset(cx + w, top + h - .5f), 1f); drawLine(INK, Offset(cx, top + h + 1.5f), Offset(cx + w, top + h + 1.5f), 1f) }
            }
            x += w
        }
        y += h
    }

    fun cell(text: String, st: TextStyle = ui(10f), span: Int = 1) = Cell(listOf(AnnotatedString(text) to st), span)
    fun rcell(text: AnnotatedString, st: TextStyle = num(10f)) = Cell(listOf(text to st), right = true)
    fun rcell(text: String, st: TextStyle = num(10f)) = rcell(AnnotatedString(text), st)
    fun th(text: String, right: Boolean = false) = Cell(listOf(AnnotatedString(text) to ui(9f, 600)), right = right, th = true)

    /* ---------- the parts of the report ---------- */

    /** Builder and customer, then the project with its address and location (prototype .tb). */
    fun parties() {
        val lab = ui(8.5f, 400, INK3); val v = ui(10f)
        fun party(k: String, name: String, phone: String) = Cell(listOf(AnnotatedString(t(k)) to lab, AnnotatedString(dn(name, l).ifBlank { "—" } + "\n" + Phone.format(phone)) to v))
        val proj = buildAnnotatedString {
            append(dn(sn.name, l)); if (sn.address.isNotBlank()) append(", " + dn(sn.address, l))
            // a builder's report only (an older snapshot has no trade: ""); furniture and trades never print it
            sn.location?.takeIf { sn.industry == "build" || (sn.industry == "" && sn.furniture.isEmpty()) }?.let { append("\n"); withStyle(SpanStyle(color = INK3, fontSize = 8.5.sp)) { append(t("pr.location") + ":") }; append(" %.5f, %.5f".format(java.util.Locale.ROOT, it.lat, it.lng)) }
        }
        table(listOf(
            listOf(party(makerKey, sn.builderName, sn.builderPhone), party("rpt.customer", sn.customer, sn.phone)),
            listOf(Cell(listOf(AnnotatedString(t("r.project")) to lab, proj to v), span = 2))
        ), fixed = floatArrayOf(CW / 2, CW / 2), breakable = false)
    }

    private fun prov(r: Room, k: String) = buildAnnotatedString {
        if (r.dim(k).v == null) withStyle(SpanStyle(color = PROV, fontStyle = FontStyle.Italic, fontFamily = face)) { append(" (" + t("r.prov") + ")") }
    }

    private fun roomRows(r: Room): List<List<Cell>> {
        val rows = ArrayList<List<Cell>>()
        val m = mUnit()
        fun v(mm: Int?, k: String?) = buildAnnotatedString { append((len(mm) + " " + m).replace(' ', NBSP)); if (k != null) append(prov(r, k)) }
        if (r.isPoly) {
            val g = polyGeo(r, sn.snap)
            g.walls.forEach { w ->
                rows += listOf(cell(t("op.wall") + " " + w.id), rcell(buildAnnotatedString {
                    append((len(w.len) + " " + m).replace(' ', NBSP))
                    if (w.derived || w.id in g.computed) withStyle(SpanStyle(color = PROV, fontStyle = FontStyle.Italic, fontFamily = face)) { append(" (" + t("sk.calc") + ")") } else append(prov(r, w.id))
                }))
            }
            r.poly!!.diags.forEach { d -> rows += listOf(cell(t("sk.diagName", "d" to d.id) + ", ${d.a + 1}–${d.b + 1}"), rcell(v(r.dim(d.id).v, d.id))) }
        } else {
            rows += listOf(cell(t("r.len")), rcell(v(r.dim("A").v, "A")))
            rows += listOf(cell(t("r.wid")), rcell(v(r.dim("B").v, "B")))
        }
        rows += listOf(cell(t("r.h")), rcell(v(r.dim("H").v, "H")))
        val a = areas(r, sn.snap)
        val m2 = t("u.m2")
        if (a != null) {
            rows += listOf(cell(t("rp.floorArea")), rcell(fmtArea(a.floor, en) + NBSP + m2))
            rows += listOf(cell(t("rp.perim")), rcell((len(a.perim.toInt()) + " " + m).replace(' ', NBSP)))
            if (a.net != null) {
                rows += listOf(cell(t("rp.gross")), rcell(fmtArea(a.gross!!, en) + NBSP + m2))
                rows += listOf(cell(t("rp.openings")), rcell(fmtArea(a.open ?: 0, en) + NBSP + m2))
                rows += listOf(cell(t("rp.net"), ui(10f, 700)), rcell(fmtArea(a.net, en) + NBSP + m2, num(10f, 700)))
            }
        }
        r.openings.forEach { o ->
            // the line says "m": its sizes are in metres whatever the length unit
            fun lm(mm: Int) = fmtLen(mm, LenUnit.M, en)
            rows += listOf(cell(t("r.op", "o" to t(if (o.type == "door") "op.door" else "op.window"), "w" to o.wall, "wd" to lm(o.w), "h" to lm(o.h),
                "off" to (if (o.offDrag) "≈ " else "") + lm(o.off), "s" to if (o.type == "window") t("r.sill", "s" to lm(o.sill)) else ""), span = 2))
        }
        val H = r.dim("H").v
        if (a?.net != null && H != null) {
            val vol = "%.2f".format(java.util.Locale.ROOT, a.floor.toDouble() * H / 1e9).replace('.', if (en) '.' else ',')
            rows += listOf(cell(t("ri.volume")), rcell(vol + NBSP + t("u.m") + "³"))
        }
        return rows
    }

    /** "1. Mehmonxona, 1-qavat", the plan (270 px wide, framed) beside the measurements (prototype roomBlock). */
    fun roomBlock(r: Room, i: Int, floorLabel: String) {
        val pf = sn.pdf
        if (!pf.plan && !pf.dims) return
        val planH = if (pf.plan) reportPlanHeight(r, sn.snap) * .75f + 1.5f else 0f
        val rows = if (pf.dims) roomRows(r) else emptyList()
        val tx = if (pf.plan) PX + 271.5f + 14f else PX; val tw = PX + CW - tx
        // the block's height before drawing it, to move the whole room to the next page when it does not fit
        val tableH = if (pf.dims) {
            val cw = widths(rows, tw, null)
            rows.sumOf { r0 -> var c = 0; r0.maxOf { cell -> val w = (c until c + cell.span).sumOf { cw[it].toDouble() }.toFloat(); c += cell.span; cellHeight(cell, w) }.toDouble() }.toFloat() + 16f
        } else 0f
        // "1. Oshxona, Oshxona": a workspace named as its room (or none) is not said twice
        val head = if (floorLabel.isBlank() || floorLabel.trim().equals(dn(r.name, l).trim(), ignoreCase = true)) "$i. " + dn(r.name, l)
            else t("r.room", "i" to i, "n" to dn(r.name, l), "f" to floorLabel)
        val title = measure(head, ui(12f, 600), CW)
        if (!fits(12f + title.size.height + 4f + max(planH, tableH))) newPage()
        h2(head)
        space(0f)
        val top = y
        if (pf.plan) {
            val label = dn(r.name, l)
            val tm2 = tm; val un = unit; val e = en; val m2 = t("u.m2")
            draw {
                translate(PX + .75f, top + .75f) { scale(.75f, .75f, Offset.Zero) { drawReportPlan(r, un, e, label, tm2, sn.snap, sn.roomLabel, m2) } }
                drawRect(FIG, Offset(PX + .375f, top + .375f), Size(270.75f, planH - .75f), style = Stroke(.75f))
            }
        }
        if (pf.dims) { y = top; pend = 0f; table(rows, tx, tw, breakable = false) }
        y = max(top + planH, if (pf.dims) y + 10f else top); pend = 0f
    }

    /**
     * Drawings and photos chosen for the report, two a page (prototype extraPages, figures): each in a light frame the
     * page's width and at most 292 high, with its name, workspace and caption under it; photos add a footnote.
     */
    fun figurePages() {
        val figs = sn.extras.filter { it.kind != "note" }
        if (figs.isEmpty()) return
        val f = uz.metrx.app.ui.markup.MkFmt(unit, en, mUnit(), l, face)
        figs.chunked(2).forEach { two ->
            newPage(); h2(t("r.extras")); space(0f)
            two.forEach { x ->
                val it = x.asItem()
                val vb = uz.metrx.app.ui.markup.mkViewBox(it, uz.metrx.app.ui.markup.MkMode.REPORT)
                val fh = minOf(CW * vb.height / vb.width, 292f) + 2f
                val cap = measure(buildAnnotatedString {
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(dn(x.name, l)) }; append(", "); append(x.ws)
                    if (x.caption.isNotBlank()) { append(". "); append(dn(x.caption, l)) }
                }, ui(9.5f, 400, INK3), CW)
                space(0f)
                val top = y
                val photo = x.src?.let { s0 -> image(s0) }
                val tm2 = tm
                draw {
                    drawRect(Color.White, Offset(PX, top), Size(CW, fh))
                    drawMarkup(it, photo, androidx.compose.ui.geometry.Rect(PX + 1f, top + 1f, PX + CW - 1f, top + fh - 1f), f, tm2, uz.metrx.app.ui.markup.MkMode.REPORT)
                    drawRect(FIG, Offset(PX + .5f, top + .5f), Size(CW - 1f, fh - 1f), style = Stroke(1f))
                    drawText(cap, topLeft = Offset(PX, top + fh + 4f))
                }
                y += fh + 4f + cap.size.height; after(12f)
            }
            if (two.any { it.kind == "photo" }) fn(t("r.photoNote"))
        }
    }

    /** Notes chosen for the report (prototype extraPages, notes part). */
    fun notesPages() {
        val notes = sn.extras.filter { it.kind == "note" }
        if (notes.isEmpty()) return
        newPage(); h2(t("r.notesH"))
        notes.forEach { n ->
            val head = buildAnnotatedString { withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(dn(n.name, l).ifBlank { t("it.untitled") }) }; append(" "); withStyle(SpanStyle(color = GREY)) { append(n.ws) } }
            val parts = ArrayList<TextLayoutResult>()
            parts += measure(head, ui(10f), CW)
            val text = dn(n.text, l)
            val p = if (text.isNotBlank()) measure(text, ui(10f), CW) else null
            val ul = if (n.checks.isNotEmpty()) measure(n.checks.joinToString("\n") { (if (it.done) "☑ " else "☐ ") + dn(it.text, l) }, ui(10f), CW) else null
            val h = parts[0].size.height + (p?.let { 3f + it.size.height } ?: 0f) + (ul?.let { 4f + it.size.height } ?: 0f) + 8f + 1f
            space(0f); if (y + h > LIMIT) { newPage(); h2(t("r.notesH")); space(0f) }
            val top = y
            draw {
                var yy = top
                drawText(parts[0], topLeft = Offset(PX, yy)); yy += parts[0].size.height
                p?.let { yy += 3f; drawText(it, topLeft = Offset(PX, yy)); yy += it.size.height }
                ul?.let { yy += 4f; drawText(it, topLeft = Offset(PX, yy)); yy += it.size.height }
                drawLine(NOTE_RULE, Offset(PX, yy + 8f + .5f), Offset(PX + CW, yy + 8f + .5f), 1f)
            }
            y += h; after(10f)
        }
    }

    /** 3D views two by two (prototype .views), at most four; a picture whose file is gone gives its place to the next. */
    fun views() {
        val vs = sn.rooms.flatMap { it.room.views }.asSequence().mapNotNull { v -> image(v.img) }.take(4).toList()
        if (vs.isEmpty()) return
        h2(t("r.views"))
        space(0f)
        val w = (CW - 8f) / 2
        vs.chunked(2).forEach { pair ->
            val h = pair.maxOf { w * it.height / it.width } + 1.5f
            if (y + h > LIMIT) { newPage(); space(0f) }
            val top = y
            pair.forEachIndexed { k, img ->
                val x = PX + k * (w + 8f); val ih = w * img.height / img.width
                draw {
                    drawImage(img, srcOffset = androidx.compose.ui.unit.IntOffset.Zero, srcSize = androidx.compose.ui.unit.IntSize(img.width, img.height),
                        dstOffset = androidx.compose.ui.unit.IntOffset((x + .75f).toInt(), (top + .75f).toInt()), dstSize = androidx.compose.ui.unit.IntSize((w - 1.5f).toInt(), (ih - 1.5f).toInt()))
                    drawRect(FIG, Offset(x + .375f, top + .375f), Size(w - .75f, ih - .75f), style = Stroke(.75f))
                }
            }
            y += h + 8f
        }
        pend = 0f
    }

    /** Materials, labour and the grand total (prototype estimate page). */
    fun estimate(e: Estimate) {
        val mats = e.materials; val labs = e.labor
        var m = BigInteger.ZERO; var lb = BigInteger.ZERO
        mats.forEach { m += lineTotal(it.qty, it.price, sn.precision) }
        labs.forEach { r -> parseDec(r.amount, sn.precision).value()?.let { lb += it } }
        h2(t("r.mat"))
        val mr = ArrayList<List<Cell>>()
        mr += listOf(th(t("r.c.no")), th(t("r.c.name")), th(t("r.c.unit")), th(t("r.c.qty"), true), th(t("r.c.price"), true), th(t("r.c.sum"), true))
        mats.forEachIndexed { j, x ->
            mr += listOf(cell("${j + 1}"), cell(dn(x.name, l)), cell(dn(x.unit, l)), rcell(fmtNumStr(x.qty, en).replace(' ', NBSP)),
                rcell(money(parseDec(x.price, sn.precision).value() ?: BigInteger.ZERO)), rcell(money(lineTotal(x.qty, x.price, sn.precision))))
        }
        mr += listOf(cell(t("r.total"), ui(10f, 700), span = 5), rcell(money(m), num(10f, 700)))
        table(mr, head = 1)
        h2(t("r.lab"))
        val lr = ArrayList<List<Cell>>()
        lr += listOf(th(t("r.c.no")), th(t("r.c.name")), th(t("r.c.sum"), true))
        labs.forEachIndexed { j, x -> lr += listOf(cell("${j + 1}"), cell(dn(x.name, l)), rcell(money(parseDec(x.amount, sn.precision).value() ?: BigInteger.ZERO))) }
        lr += listOf(cell(t("r.total"), ui(10f, 700), span = 2), rcell(money(lb), num(10f, 700)))
        table(lr, head = 1)
        ensure(30f)
        table(listOf(listOf(cell(t("r.grand"), ui(11f, 700)), Cell(listOf(AnnotatedString(money(m + lb) + NBSP + curSuffix(sn.currency, l)) to num(11f, 700)), right = true, dbl = true))), breakable = false)
    }

    /** Builder's and customer's signature lines (prototype .sig). */
    fun signatures(maker: String = "r.sigB") {
        val w = (CW - 30f) / 2
        val a = measure(t(maker), ui(9f, 400, INK3), w); val b = measure(t("r.sigC"), ui(9f, 400, INK3), w)
        val h = .75f + 3f + max(a.size.height, b.size.height)
        space(22f); if (y + h > LIMIT) { newPage(); space(22f) }
        val top = y
        draw {
            drawLine(INK, Offset(PX, top + .375f), Offset(PX + w, top + .375f), .75f); drawText(a, topLeft = Offset(PX, top + 3.75f))
            drawLine(INK, Offset(PX + w + 30f, top + .375f), Offset(PX + CW, top + .375f), .75f); drawText(b, topLeft = Offset(PX + w + 30f, top + 3.75f))
        }
        y += h; after(0f)
    }

    /** The page number and the project's name at the bottom, and the DRAFT mark across a draft (prototype .pf, .wmk). */
    fun finish(): List<RPage> {
        val n = pages.size
        val name = dn(sn.name, l)
        val mark = measure(t("r.mark"), num(86f, 700).copy(color = WMK, letterSpacing = .1.em, lineHeight = 100.sp))
        return pages.mapIndexed { i, list ->
            val left = measure(name, ui(8.5f, 400, GREY), CW / 2); val right = measure(t("r.page", "i" to i + 1, "n" to n), ui(8.5f, 400, GREY))
            RPage {
                drawRect(Color.White, Offset.Zero, Size(PAGE_W, PAGE_H))
                if (draft) rotate(-30f, Offset(PAGE_W / 2, PAGE_H * .46f)) { drawText(mark, topLeft = Offset(PAGE_W / 2 - mark.size.width / 2f, PAGE_H * .46f - mark.size.height / 2f)) }
                list.forEach { it() }
                val fy = PAGE_H - 20f - left.size.height
                drawText(left, topLeft = Offset(PX, fy)); drawText(right, topLeft = Offset(PAGE_W - PX - right.size.width, fy))
            }
        }
    }
}

/**
 * The report's pages for [sn]: the parties and the first room, two rooms a page after that, the notes, then the views,
 * the estimate, the notes to the customer and the signatures. A [draft] says so in its title and across every page.
 */
fun reportPages(tm: TextMeasurer, sn: Snap, draft: Boolean, meta: QuoteMeta?, image: (String) -> ImageBitmap?, now: Long = System.currentTimeMillis(),
                design: Boolean = false): List<RPage> {
    // [design]: a tiler's simple app shares the design: dated, no draft mark (its snapshot has no estimate)
    val d = Doc(tm, sn, draft && !design, meta, image, now)
    if (design) { d.quoteTitle = "rpt.design"; d.subLine = uz.metrx.app.data.fmtDate(now) }
    // a trade's order names its own maker (tiler, electrician…), not the builder
    val trade = sn.industry in uz.metrx.app.trades.TRADES
    if (trade) d.makerKey = "rpt.maker.${sn.industry}"
    val rooms = sn.rooms
    d.newPage(); d.parties()
    // with the plans and the measurements both off the rooms print nothing: no empty pages for them
    val roomsOn = sn.pdf.plan || sn.pdf.dims
    if (roomsOn) {
        rooms.firstOrNull()?.let { d.roomBlock(it.room, 1, it.floorLabel) }
        // the note on the room model only with a room printed (an order without rooms has nothing it is about)
        if (rooms.isNotEmpty()) d.fn(d.t("r.geoNote"))
        var i = 1
        while (i < rooms.size) {
            d.newPage()
            d.roomBlock(rooms[i].room, i + 1, rooms[i].floorLabel)
            rooms.getOrNull(i + 1)?.let { d.roomBlock(it.room, i + 2, it.floorLabel) }
            i += 2
        }
    }
    // an electrician's order: the wiring plan, the walls with their points and the legend
    sn.elec?.let { e -> if (!e.empty) d.elecPages(e) }
    // a plumber's order: the pipe plan with the fixtures, the walls with their outlets, the heating and the legend
    sn.plumb?.let { e -> if (!e.empty) d.plumbPages(e) }
    // a windows-and-doors order: the summary table, then each product's drawing from inside with its sizes and make
    sn.win?.let { e -> if (!e.empty) d.winPages(e) }
    // a tiler's order: the layouts, each room's floor from above and its tiled walls
    sn.tiles?.let { ls -> d.tilePages(ls, sn.troom) }
    d.figurePages()
    d.notesPages()
    // the first page holding only the parties has room for the rest
    if (roomsOn || d.pages.size > 1) d.newPage()
    if (sn.pdf.views) d.views()
    if (sn.pdf.estimate) d.estimate(sn.estimate)
    if (sn.notes.isNotBlank()) { d.h2(d.t("rpt.notes")); d.para(AnnotatedString(sn.notes), d.ui(10f), 10f, 10f) }
    // the notes on quantities and money are the estimate's
    // a trade's quantities are worked out by the app from the sizes; a builder's are typed
    if (sn.pdf.estimate) { d.fn(d.t(if (trade) "r.qtyCalc" else "r.qtyNote")); d.fn(d.t("r.moneyNote", "c" to sn.currency)) }
    if (sn.pdf.sign) d.signatures(if (trade) "r.sig.${sn.industry}" else "r.sigB")
    return d.finish()
}

/** Grand total of a snapshot (for the quote's record and the dark strip). */
fun snapTotal(sn: Snap): BigInteger {
    var g = BigInteger.ZERO
    sn.estimate.materials.forEach { g += lineTotal(it.qty, it.price, sn.precision) }
    sn.estimate.labor.forEach { r -> parseDec(r.amount, sn.precision).value()?.let { g += it } }
    return g
}

/** Measurements still waiting for confirmation in the report's rooms (prototype unconfCount over sn.rooms). */
fun unconfirmed(sn: Snap): Int = sn.rooms.sumOf { sr -> uz.metrx.app.geo.unconfCount(sr.room, sn.snap) }

