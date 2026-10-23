package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.ui.win.ElevMap
import uz.metrx.app.ui.win.drawElevation
import uz.metrx.app.ui.win.openingKey
import uz.metrx.app.win.WinItem
import uz.metrx.app.win.WinOrder
import uz.metrx.app.win.ctxOf
import uz.metrx.app.win.placed
import uz.metrx.app.win.sashesOf
import java.math.BigInteger

/*
 * A windows-and-doors maker's pages in the customer's PDF: a summary table of every product (its room and opening, its
 * size, how many, and in the advanced app its price), then each product drawn from inside with its overall and sash
 * sizes, its sash split and opening symbols, and its make: profile, glass, colours, extras, room and opening. Prices
 * only with the estimate (the advanced app); the parts' lines stay in the estimate pages.
 */

private val FRAME = Color(0xFFC3CEDF)

internal fun Doc.winPages(e: WinOrder) {
    // every room (a window in a room left out of the report still has its room and opening)
    val all = sn.rooms + sn.calcRooms
    val p = Project("snap", sn.name, rooms = all.map { it.room }, industry = "win", win = e)
    val items = e.items
    if (items.isEmpty()) return
    val withPrice = sn.pdf.estimate && sn.winPrice.isNotEmpty()
    val scale = BigInteger.TEN.pow(sn.precision.coerceIn(0, 4))
    fun price(id: String) = sn.winPrice[id]?.let { money(BigInteger.valueOf(it) * scale) + " " + sn.currency }
    val roomOf = all.associate { it.room.id to tradeRoomName(it, all, l) }
    fun title(it: WinItem) = it.name.ifBlank { t("dw.k.${it.kind}") }
    fun where(it: WinItem): String {
        if (!it.inRoom) return t("dw.noRoom")
        val r = p.rooms.firstOrNull { r -> r.id == it.roomId } ?: return t("dw.noRoom")
        val o = r.openings.firstOrNull { o -> o.id == it.opening }
        return (roomOf[r.id] ?: dn(r.name, l)) + (o?.let { x -> val (k, n) = openingKey(r, x); " · " + t(k, "n" to n) + " · " + t("tl.wallN", "w" to x.wall) } ?: "")
    }
    // on the page in hand when it has room (no near-empty first page)
    ensure(260f)
    h2(t("dw.r.title"))
    val rows = ArrayList<List<Cell>>()
    rows += listOfNotNull(th("№"), th(t("dw.r.item")), th(t("dw.r.where")), th(t("dw.r.size"), true), th(t("dw.r.qty"), true), if (withPrice) th(t("dw.r.price"), true) else null)
    items.forEachIndexed { i, it ->
        rows += listOfNotNull(rcell("${i + 1}"), cell(title(it)), cell(where(it)), rcell("${it.w} × ${it.h}"), rcell("${it.qty}"), if (withPrice) rcell(price(it.id) ?: "—") else null)
    }
    table(rows, head = 1)
    // each product's price on its own (rounded up per product); the order's total is the estimate's
    if (withPrice) fn(t("dw.r.priceNote"))
    fn(t("dw.r.note"))
    // each product: its drawing from inside on the left, what it is made of on the right
    val bw = CW * .56f; val bh = 210f
    items.forEachIndexed { i, it ->
        val cap = measure("${i + 1}. " + title(it), ui(10.5f, 700), CW)
        val spec = specOf(it, where(it), if (withPrice) price(it.id) else null)
        val sp = measure(spec, ui(8.5f, 400), CW - bw - 16f)
        val need = cap.size.height + 4f + maxOf(bh, sp.size.height.toFloat())
        ensure(need + 6f); space(8f)
        val top = y
        draw {
            drawText(cap, topLeft = Offset(PX, top))
            val bt = top + cap.size.height + 4f
            drawRect(Color.White, Offset(PX, bt), Size(bw, bh))
            drawElevation(it, ElevMap(it.w.toDouble(), it.h.toDouble(), Rect(PX, bt, PX + bw, bt + bh), 18f, 34f, 6f), label = { s -> measure(s, ui(6.5f, 600)) },
                small = { s -> measure(s, ui(5.5f, 500)) }, stroke = 1f)
            drawRect(FRAME, Offset(PX + .5f, bt + .5f), Size(bw - 1f, bh - 1f), style = Stroke(.75f))
            drawText(sp, topLeft = Offset(PX + bw + 16f, bt))
        }
        y += need; after(10f)
    }
}

/** What product [it] is made of, line by line, in the report's language. */
private fun Doc.specOf(it: WinItem, where: String, price: String?): String {
    val lines = ArrayList<String>()
    lines += t("dw.r.at", "w" to where)
    val c = if (it.inRoom) ctxOf(Project("s", "", rooms = (sn.rooms + sn.calcRooms).map { r -> r.room }), it.roomId!!, sn.snap) else null
    val o = c?.let { x -> placed(x, it)?.o }
    if (o != null) lines += t("dw.r.op", "s" to "${o.w} × ${o.h}", "g" to it.gap)
    lines += t("dw.r.sizeL", "s" to "${it.w} × ${it.h}") + if (!it.inRoom && it.qty > 1) " · " + t("dw.qtyN", "n" to it.qty) else ""
    if (it.isDoor) {
        lines += t(if (it.kind == "dsl") "dw.slide${it.hinge}" else "dw.hinge${it.hinge}") + if (it.kind != "dsl") " · " + t("dw.swing.${it.swing}") else ""
        lines += t("dw.colDoor") + ": " + t("dw.col.${it.colIn}")
    } else {
        lines += t("dw.p.${it.profile}") + ", " + (if (it.profile == "alu") t(if (it.chambers >= 3) "dw.alu.warm" else "dw.alu.cold") else t("dw.chN", "n" to it.chambers))
        lines += t("dw.g.${it.glass}")
        lines += t("dw.colIn") + ": " + t("dw.col.${it.colIn}") + " · " + t("dw.colOut") + ": " + t("dw.col.${it.colOut}")
        sashesOf(it).forEachIndexed { i, s ->
            val h = if (s.t == "turn" || s.t == "tt") " (" + t("dw.hinge${s.cell.hinge}") + ")" else if (s.t == "slide") " (" + t("dw.slide${s.cell.hinge}") + ")" else ""
            lines += t("dw.sashN", "n" to i + 1) + ": " + t("dw.t.${s.t}") + h + ", ${Math.round(s.r.w)} × ${Math.round(s.r.h)}"
        }
        val ex = listOfNotNull(if (it.sill > 0) t("dw.x.sill") + " ${it.sill} " + t("dw.mm") else null, if (it.drip) t("dw.x.drip") else null, if (it.reveals) t("dw.x.reveals") else null,
            if (it.net) t("dw.x.net") else null, if (it.handles) t("dw.x.handles") else null)
        if (ex.isNotEmpty()) lines += t("dw.extras") + ": " + ex.joinToString(", ")
    }
    if (price != null) lines += t("dw.r.price") + ": " + price
    return lines.joinToString("\n")
}
