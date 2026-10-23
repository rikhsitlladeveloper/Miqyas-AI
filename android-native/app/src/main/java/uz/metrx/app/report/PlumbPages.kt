package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.plumb.PlumbOrder
import uz.metrx.app.plumb.UFH_RGB
import uz.metrx.app.plumb.calcOf
import uz.metrx.app.plumb.fixesIn
import uz.metrx.app.plumb.kindRgb
import uz.metrx.app.plumb.pointsIn
import uz.metrx.app.plumb.radWatts
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.elec.WallMap
import uz.metrx.app.ui.elec.rgbC
import uz.metrx.app.ui.plumb.drawPlumbPlan
import uz.metrx.app.ui.plumb.drawPlumbWall
import uz.metrx.app.ui.plumb.fixSymbol
import uz.metrx.app.ui.plumb.legendFix
import uz.metrx.app.ui.plumb.riserSymbol
import uz.metrx.app.ui.plumb.runsIn

/*
 * A plumber's pages in the customer's PDF: the pipe system, the fixtures room by room, the legend of symbols and pipe
 * colours, the heating; then each room from above with its fixtures, riser, pipes and underfloor loops, and each wall
 * with its fixtures and outlets at their heights. Pipe lengths only in the advanced app's PDF (with the estimate);
 * prices stay in the estimate pages.
 */

private val FRAME = Color(0xFFC3CEDF)

internal fun Doc.plumbPages(e: PlumbOrder) {
    // worked out with every room (the riser's room may be left out of the report); only the report's rooms are drawn
    val all = sn.rooms + sn.calcRooms
    val p = Project("snap", sn.name, rooms = all.map { it.room }, industry = "plumb", plumb = e)
    val calc = calcOf(p, sn.snap)
    val shown = sn.rooms.map { it.room.id }.toSet()
    fun drawn(c: uz.metrx.app.plumb.PCtx) = c.free != null || c.id in shown
    if (calc.ctxs.none { fixesIn(p, it).isNotEmpty() || pointsIn(p, it).isNotEmpty() || it.pr.ufh }) return
    val dec = { s: String -> if (en) s else s.replace('.', ',') }
    fun d1(v: Double) = dec(String.format(java.util.Locale.ROOT, "%.1f", v))
    val names = calc.ctxs.associate { c -> c.id to (c.free?.name?.ifBlank { t("sx.k.${c.free.kind}") } ?: all.firstOrNull { it.room.id == c.id }?.let { it.floorLabel.ifBlank { dn(it.room.name, l) } } ?: "") }
    // on the page in hand when it has room (no near-empty first page)
    ensure(260f)
    h2(t("sx.r.title"))
    val rs = calc.routes.riser
    para(androidx.compose.ui.text.AnnotatedString(t("sx.r.system", "s" to t("sx.sys.${e.water}"), "r" to t("sx.run.${e.run}"), "h" to t("sx.run.${e.hrun}")) +
        (rs?.let { " " + t("sx.r.riser", "r" to (names[it.roomId] ?: ""), "w" to it.wall) } ?: "")), ui(9.5f, 400), 2f, 6f)
    // the fixtures room by room
    val withLen = sn.pdf.estimate
    val rows = ArrayList<List<Cell>>()
    rows += listOfNotNull(th(t("sx.r.room")), th(t("sx.fixes")), th(t("sx.points"), true), if (withLen) th(t("sx.r.pipe"), true) else null)
    calc.ctxs.forEach { c ->
        val fs = fixesIn(p, c)
        val pts = pointsIn(p, c, fs)
        if (fs.isEmpty() && pts.isEmpty() && !c.pr.ufh || !drawn(c)) return@forEach
        val what = uz.metrx.app.plumb.FIX_TYPES.mapNotNull { ty -> fs.count { it.t == ty.id }.takeIf { it > 0 }?.let { n -> (if (n > 1) "$n × " else "") + t("sx.t.${ty.id}") } } +
            (if (c.pr.ufh) listOf(t("sx.s.ufh")) else emptyList())
        rows += listOfNotNull(cell(names[c.id] ?: ""), cell(what.joinToString(", ").ifEmpty { "—" }), rcell("${pts.size}"),
            if (withLen) rcell(d1(runsIn(calc.routes, c.id).sumOf { it.len } / 1000) + " " + t("u.m")) else null)
    }
    table(rows, head = 1)
    if (withLen) {
        val k = calc.count
        val lens = ArrayList<List<Cell>>()
        lens += listOf(th(t("sx.r.kind")), th(t("sx.r.len"), true))
        listOf("cold", "hot", "hs", "hr").forEach { kind -> calc.routes.lenOf(kind).takeIf { it > 0 }?.let { lens += listOf(cell(t("sx.o.$kind")), rcell(d1(it / 1000) + " " + t("u.m"))) } }
        if (k.drain110 > 0) lens += listOf(cell(t("sx.c.drain", "d" to 110)), rcell(d1(k.drain110) + " " + t("u.m")))
        if (k.drain50 > 0) lens += listOf(cell(t("sx.c.drain", "d" to 50)), rcell(d1(k.drain50) + " " + t("u.m")))
        if (k.ufhM > 0) lens += listOf(cell(t("sx.c.ufh")), rcell(d1(k.ufhM) + " " + t("u.m")))
        if (lens.size > 1) { table(lens, head = 1); fn(t("sx.r.lenNote")) }
    }
    // the legend: fixtures, the riser, the pipes' colours
    val types = legendFix(calc.ctxs.flatMap { fixesIn(p, it) })
    h2(t("el.r.legend"))
    val colW = CW / 3
    (types + (if (rs != null) listOf("riser") else emptyList())).chunked(3).forEach { row ->
        ensure(18f); space(0f)
        val top = y
        val labels = row.map { k -> measure(if (k == "riser") t("sx.riser") else t("sx.t.$k"), ui(8.5f, 400), colW - 24f) }
        val h = maxOf(16f, labels.maxOf { it.size.height.toFloat() })
        draw {
            row.forEachIndexed { i, k ->
                val x = PX + i * colW
                if (k == "riser") riserSymbol(Offset(x + 9f, top + h / 2), 6f, rs?.hot ?: true) else fixSymbol(k, Offset(x + 9f, top + h / 2), 7f)
                drawText(labels[i], topLeft = Offset(x + 22f, top + (h - labels[i].size.height) / 2))
            }
        }
        y += h + 3f
    }
    ensure(16f); space(0f)
    val gTop = y
    val kinds = listOf("cold", "hot", "drain", "hs", "hr").filter { k -> calc.routes.runs.any { it.kind == k } || (k == "drain" && calc.routes.drains.isNotEmpty()) }
    val keys = kinds.map { "sx.o.$it" } + (if (calc.routes.loops.isNotEmpty()) listOf("sx.s.ufh") else emptyList())
    val gLab = keys.map { measure(t(it), ui(8.5f, 400)) }
    draw {
        var x = PX
        keys.forEachIndexed { i, k ->
            val rgb = if (k == "sx.s.ufh") UFH_RGB else kindRgb(k.removePrefix("sx.o."))
            drawLine(rgbC(rgb), Offset(x, gTop + 7f), Offset(x + 14f, gTop + 7f), if (k == "sx.o.drain") 4f else 2.5f)
            drawText(gLab[i], topLeft = Offset(x + 18f, gTop + 7f - gLab[i].size.height / 2)); x += 18f + gLab[i].size.width + 12f
        }
    }
    y += 16f; after(6f)
    // the heating
    val rads = calc.ctxs.flatMap { c -> fixesIn(p, c).filter { it.t == "rad" }.map { c to it } }
    if (rads.isNotEmpty() || calc.routes.loops.isNotEmpty()) {
        h2(t("sx.s.heat"))
        val hr = ArrayList<List<Cell>>()
        hr += listOf(th(t("sx.r.room")), th(t("sx.heatNeed"), true), th(t("sx.t.rad"), true), th(t("sx.s.ufh")))
        calc.ctxs.forEach { c ->
            val rr = rads.filter { it.first.id == c.id }.map { it.second }
            val lp = calc.routes.loops.firstOrNull { it.roomId == c.id }
            if (rr.isEmpty() && lp == null || !drawn(c)) return@forEach
            hr += listOf(cell(names[c.id] ?: ""), rcell("${(c.areaM2 * uz.metrx.app.plumb.W_M2).toInt()} W"),
                rcell(if (rr.isEmpty()) "—" else "${rr.size} · ${rr.sumOf { radWatts(it) }} W"),
                cell(lp?.let { t("sx.loopV", "n" to it.n, "s" to it.step / 10, "a" to d1(it.area)) + " · " + d1(it.each / 1000) + " " + t("u.m") } ?: "—"))
        }
        table(hr, head = 1)
        fn(t("sx.r.heatNote"))
    }
    if (calc.warns.isNotEmpty()) fn(t("sx.r.warn", "n" to calc.warns.size))
    fn(t("sx.r.note"))
    // each room: from above, then the walls with fixtures or outlets
    calc.ctxs.forEach { c ->
        val fs = fixesIn(p, c)
        val pts = pointsIn(p, c, fs)
        val runs = runsIn(calc.routes, c.id)
        val loop = calc.routes.loops.firstOrNull { it.roomId == c.id }
        if (fs.isEmpty() && pts.isEmpty() && runs.isEmpty() && loop == null || !drawn(c)) return@forEach
        newPage()
        h2(t("sx.r.roomT", "r" to (names[c.id] ?: "")))
        space(0f)
        val ph = 250f; val top = y
        draw {
            drawRect(Color.White, Offset(PX, top), Size(CW, ph))
            drawPlumbPlan(c, PlanMap(c.g.floor, Rect(PX, top, PX + CW, top + ph), 16f), fs, pts, rs, runs, loop, 5.5f)
            drawRect(FRAME, Offset(PX + .5f, top + .5f), Size(CW - 1f, ph - 1f), style = Stroke(.75f))
        }
        y += ph; after(8f)
        val ws = c.g.walls.filter { w -> pts.any { it.wall == w.id } || fs.any { it.wall == w.id } || (rs?.let { it.roomId == c.id && it.wall == w.id } == true) }
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
                    drawPlumbWall(c, w, WallMap(w.len, c.g.H, Rect(x, bt, x + bw, bt + bh), 10f, 12f), fs, pts, rs, runs,
                        { s -> measure(if (s == "riser") t("sx.riser") else len(s.toIntOrNull()), ui(6.5f, 600)) }, minR = 3f)
                    drawRect(FRAME, Offset(x + .5f, bt + .5f), Size(bw - 1f, bh - 1f), style = Stroke(.75f))
                }
            }
            y += need; after(10f)
        }
    }
}
