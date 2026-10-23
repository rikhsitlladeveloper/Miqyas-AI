package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import uz.metrx.app.data.Snap
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.LABEL_COLS
import uz.metrx.app.furniture.LABEL_ROWS
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.PartLabel
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.labelId
import uz.metrx.app.furniture.labelSlot
import uz.metrx.app.furniture.labelsOf

/*
 * The part labels' pages (bazis ideas, 23 Oct 2026; furniture/Labels.kt): an A4 sheet of 3 × 8 stickers, 70 × 37 mm,
 * edge to edge as the usual sticker sheets are. Each one: the part and its number, its finished size, a small drawing
 * of the part with its banded edges, the material, the piece and module, the order; the QR code with the part's id when
 * asked for.
 */

private val L_INK = Color(0xFF0E1C36)
private val L_GREY = Color(0xFF5F6B82)
private val L_CUT = Color(0xFFDCE4F0)

/** The stickers of the order in [sn] ([order] its id, for the QR codes); [qr] with a QR code each. */
fun labelPages(tm: TextMeasurer, sn: Snap, ws: Workshop, mats: List<Mat>, order: String, qr: Boolean, now: Long = System.currentTimeMillis()): List<RPage> {
    val d = Doc(tm, sn, false, null, { null }, now)
    val labels = labelsOf(labelled(sn.furniture), ws)
    if (labels.isEmpty()) return emptyList()
    val cw = PAGE_W / LABEL_COLS; val rh = PAGE_H / LABEL_ROWS
    fun matName(id: String) = mats.firstOrNull { it.id == id }?.let { d.presetName(it.id, it.name) } ?: id
    // the order and its customer (once, when the order is named after them)
    val orderLine = listOf(dn(sn.name, d.l), sn.customer.takeIf { it.isNotBlank() && !dn(sn.name, d.l).contains(it) } ?: "").filter { it.isNotBlank() }.joinToString(" · ")
    fun one(s: String, st: androidx.compose.ui.text.TextStyle, w: Float): TextLayoutResult =
        tm.measure(s, st, overflow = TextOverflow.Ellipsis, maxLines = 1, density = Density(1f), constraints = Constraints(maxWidth = w.toInt().coerceAtLeast(1)))
    // a sticker's drawing, its texts measured first (outside the page's drawing)
    class Sticker(val lb: PartLabel, val page: Int, val x: Float, val y: Float, val texts: List<Pair<TextLayoutResult, Offset>>, val code: QrCode?, val glyph: Offset)
    val pad = 8f
    val qs = if (qr) 50f else 0f
    val stickers = labels.mapIndexed { i, lb ->
        val (pg, c, r) = labelSlot(i)
        val x = c * cw; val y = r * rh
        val tw = cw - 2 * pad - (if (qr) qs + 6f else 0f)
        val t = ArrayList<Pair<TextLayoutResult, Offset>>()
        val name = one(d.t(lb.key) + if (lb.grain) " ↕" else "", d.ui(9f, 700), tw - 28f)
        t += name to Offset(x + pad, y + pad)
        val no = one("№${lb.n}", d.num(9f, 700), 40f)
        t += no to Offset(x + pad + tw - no.size.width, y + pad)
        val size = one("${lb.L} × ${lb.W}", d.num(15f, 700), tw - 16f)
        t += size to Offset(x + pad, y + pad + 15f)
        t += one(d.t("u.mm"), d.ui(7.5f, 500, L_GREY), 30f) to Offset(x + pad + size.size.width + 3f, y + pad + 22f)
        // the material and the piece beside the part's drawing
        t += one(dn(matName(lb.mat), d.l), d.ui(7.5f, 500), tw - 48f) to Offset(x + pad, y + pad + 40f)
        t += one(dn(lb.piece, d.l) + if (lb.mod.isNotEmpty()) " · " + lb.mod else "", d.ui(7.5f, 600), tw - 48f) to Offset(x + pad, y + pad + 52f)
        t += one(orderLine, d.ui(7f, 400, L_GREY), tw) to Offset(x + pad, y + pad + 64f)
        val code = if (qr) qrOf(labelId(order, lb.n)) else null
        if (code != null) t += one(labelId(order, lb.n), d.num(5.5f, 500), qs + 8f) to Offset(x + cw - pad - qs, y + pad + qs + 1f)
        Sticker(lb, pg, x, y, t, code, Offset(x + pad + tw - 40f, y + pad + 41f))
    }
    return stickers.groupBy { it.page }.toSortedMap().values.map { list ->
        RPage {
            drawRect(Color.White, Offset.Zero, Size(PAGE_W, PAGE_H))
            list.forEach { s ->
                // the cutting line round the sticker, light (a sticker sheet is cut already; on plain paper it guides the scissors)
                drawRect(L_CUT, Offset(s.x, s.y), Size(cw, rh), style = Stroke(.5f))
                s.texts.forEach { (lr, o) -> drawText(lr, topLeft = o) }
                // the part, drawn small: a thick edge banded thick, a thin line thin, a dashed one not banded
                val gw = 40f; val gh = 22f; val g = s.glyph
                drawRect(Color(0xFFF3F6FA), g, Size(gw, gh))
                fun edge(code: Int, a: Offset, b: Offset) {
                    if (code == 0) drawLine(L_GREY.copy(alpha = .5f), a, b, .6f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 2f)))
                    else drawLine(L_INK, a, b, if (code == 2) 2.4f else .9f)
                }
                val bd = s.lb.bands
                edge(bd.l1, g, Offset(g.x + gw, g.y)); edge(bd.l2, Offset(g.x, g.y + gh), Offset(g.x + gw, g.y + gh))
                edge(bd.s1, g, Offset(g.x, g.y + gh)); edge(bd.s2, Offset(g.x + gw, g.y), Offset(g.x + gw, g.y + gh))
                s.code?.let { q ->
                    // a quiet zone of 4 modules round the code, as scanners want
                    val m = qs / (q.size + 8)
                    val ox = s.x + cw - pad - qs + 4 * m; val oy = s.y + pad + 4 * m
                    for (r in 0 until q.size) for (c in 0 until q.size) if (q[r, c]) drawRect(L_INK, Offset(ox + c * m, oy + r * m), Size(m + .05f, m + .05f))
                }
            }
        }
    }
}
