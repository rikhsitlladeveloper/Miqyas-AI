package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.elec.calcOf
import uz.metrx.app.elec.cableName
import uz.metrx.app.elec.devsIn
import uz.metrx.app.ui.elec.E_INK
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.elec.WallMap
import uz.metrx.app.ui.elec.devSymbol
import uz.metrx.app.ui.elec.drawElecPlan
import uz.metrx.app.ui.elec.drawElecWall
import uz.metrx.app.ui.elec.legendTypes
import uz.metrx.app.ui.elec.rgbC

/*
 * An electrician's pages in the customer's PDF: how the cable runs, the circuits with their breakers, the legend of
 * symbols, then each room from above with its routes and each wall with its points and their heights. Prices stay in
 * the estimate pages, which only the advanced app prints.
 */

private val FRAME = Color(0xFFC3CEDF)

internal fun Doc.elecPages(e: ElecOrder) {
    val p = Project("snap", sn.name, rooms = sn.rooms.map { it.room }, industry = "elec", elec = e)
    val calc = calcOf(p, sn.snap)
    if (calc.ctxs.none { devsIn(p, it).isNotEmpty() }) return
    val byDev = calc.circuits.flatMap { cc -> cc.devs.map { it.id to cc } }.toMap()
    val dec = { s: String -> if (en) s else s.replace('.', ',') }
    newPage()
    h2(t("el.r.title"))
    para(androidx.compose.ui.text.AnnotatedString(t("el.r.method", "m" to t("el.m.${e.method}")) + " " + t("el.m.${e.method}S")), ui(9.5f, 400), 2f, 6f)
    // the circuits
    val withLen = sn.pdf.estimate
    val rows = ArrayList<List<Cell>>()
    rows += listOfNotNull(th(t("r.c.no")), th(t("el.r.group")), th(t("el.r.brk")), th(t("el.r.cable")), th(t("el.r.rooms")), if (withLen) th(t("el.r.len"), true) else null)
    val names = calc.ctxs.associate { c -> c.id to (c.free?.name?.ifBlank { t("el.k.${c.free.kind}") } ?: sn.rooms.firstOrNull { it.room.id == c.id }?.let { it.floorLabel.ifBlank { dn(it.room.name, l) } } ?: "") }
    calc.circuits.forEach { cc ->
        rows += listOfNotNull(cell("${cc.no}"), cell(t("el.g.${cc.group}")), cell(if (cc.amps > 0) t("el.brkV", "a" to cc.amps) + (if (cc.rcd) ", " + t("el.rcdS") else "") else "—"),
            cell(dec(if (cc.cable == "utp") "UTP" else "VVG " + cableName(cc.cable))), cell(cc.rooms.mapNotNull { names[it] }.joinToString(", ")),
            if (withLen) rcell(dec(String.format(java.util.Locale.ROOT, "%.1f", calc.routes.cableOf(cc) / 1000)) + " " + t("u.m")) else null)
    }
    table(rows, head = 1)
    if (withLen) fn(t("el.r.lenNote"))
    // the legend
    val types = legendTypes(calc.ctxs.flatMap { devsIn(p, it) }) + "panel"
    h2(t("el.r.legend"))
    val colW = CW / 3
    types.chunked(3).forEach { row ->
        ensure(16f); space(0f)
        val top = y
        val labels = row.map { k -> measure(if (k == "panel") t("el.panel") else t("el.t.$k"), ui(8.5f, 400), colW - 22f) }
        val h = maxOf(14f, labels.maxOf { it.size.height.toFloat() })
        draw {
            row.forEachIndexed { i, k ->
                val x = PX + i * colW
                devSymbol(k, Offset(x + 8f, top + h / 2), 5f, rgbC(0x2563EB), E_INK)
                drawText(labels[i], topLeft = Offset(x + 20f, top + (h - labels[i].size.height) / 2))
            }
        }
        y += h + 3f
    }
    ensure(16f); space(0f)
    val gTop = y
    val gl = calc.circuits.map { it.group }.distinct()
    val gLab = gl.map { measure(t("el.g.$it"), ui(8.5f, 400)) }
    draw {
        var x = PX
        gl.forEachIndexed { i, g ->
            drawLine(rgbC(uz.metrx.app.elec.groupDef(g).rgb), Offset(x, gTop + 7f), Offset(x + 14f, gTop + 7f), 2.5f)
            drawText(gLab[i], topLeft = Offset(x + 18f, gTop + 7f - gLab[i].size.height / 2)); x += 18f + gLab[i].size.width + 12f
        }
    }
    y += 16f; after(6f)
    fn(t("el.r.note"))
    // each room: from above, then its walls
    calc.ctxs.forEach { c ->
        val ds = devsIn(p, c)
        val runs = calc.routes.inRoom(c.id)
        if (ds.isEmpty() && runs.isEmpty()) return@forEach
        newPage()
        h2(t("el.r.room", "r" to (names[c.id] ?: "")))
        space(0f)
        val ph = 250f; val top = y
        draw {
            drawRect(Color.White, Offset(PX, top), Size(CW, ph))
            drawElecPlan(c, PlanMap(c, Rect(PX, top, PX + CW, top + ph), 16f), ds, calc.routes.panel, runs, { byDev[it] }, 5.5f)
            drawRect(FRAME, Offset(PX + .5f, top + .5f), Size(CW - 1f, ph - 1f), style = Stroke(.75f))
        }
        y += ph; after(8f)
        val ws = c.g.walls.filter { w -> ds.any { it.wall == w.id } || (calc.routes.panel?.let { it.roomId == c.id && it.wall == w.id } == true) }
        val bw = (CW - 10f) / 2; val bh = 150f
        ws.chunked(2).forEach { two ->
            val caps = two.map { w -> measure(t("tl.wallN", "w" to w.id) + " · " + len(w.len.toInt()) + " " + mUnit(), ui(9f, 600)) }
            val need = caps.maxOf { it.size.height.toFloat() } + 3f + bh
            ensure(need + 6f); space(0f)
            val t0 = y
            draw {
                two.forEachIndexed { i, w ->
                    val x = PX + i * (bw + 10f)
                    drawText(caps[i], topLeft = Offset(x, t0))
                    val bt = t0 + caps[i].size.height + 3f
                    drawRect(Color.White, Offset(x, bt), Size(bw, bh))
                    drawElecWall(c, w, WallMap(w.len, c.g.H, Rect(x, bt, x + bw, bt + bh), 10f, 12f), ds, calc.routes.panel, runs, { byDev[it] },
                        { s -> measure(len(s.toIntOrNull()), ui(6.5f, 600)) })
                    drawRect(FRAME, Offset(x + .5f, bt + .5f), Size(bw - 1f, bh - 1f), style = Stroke(.75f))
                }
            }
            y += need; after(10f)
        }
    }
}
