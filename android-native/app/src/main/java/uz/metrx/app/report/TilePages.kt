package uz.metrx.app.report

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import uz.metrx.app.data.dn
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.TileRoom
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.floorLayout
import uz.metrx.app.tiles.layRoom
import uz.metrx.app.tiles.roomGeo
import uz.metrx.app.ui.tiles.drawLaidCapped
import uz.metrx.app.ui.tiles.placeKey

/*
 * A tiler's pages in the customer's PDF (like the electrician's and the plumber's): the layouts in a table (where, the
 * pattern, the tile and its joint, the look), then each tiled room from above with the floor's tiles and each tiled
 * wall from the front with its tiles round the doors and windows. Prices stay in the estimate pages.
 */

private val FRAME = Color(0xFFC3CEDF)
private val WALL_INK = Color(0xFF3E4A61)

/** A layout in words for the PDF: where and the pattern; the tile, its joint and look. */
private fun Doc.layoutLine(l: TileLayout) = t(placeKey(l)) + " · " + t("tl.p.${l.pattern}")
private fun Doc.layoutTile(l: TileLayout) = "${l.a} × ${l.b} ${t("u.mm")} · " + t("tl.jointV", "n" to l.joint) + (if (l.rot != 0) " · ${l.rot}°" else "")
private fun Doc.layoutLook(l: TileLayout) = t("tl.lk.${l.look}") + if (l.usesSecond) " + " + t("tl.lk.${l.look2}") else ""

internal fun Doc.tilePages(ls: List<TileLayout>, troom: List<TileRoom>) {
    if (ls.isEmpty()) return
    val names = sn.rooms.associate { it.room.id to tradeRoomName(it, sn.rooms, l) }
    // the layouts of the report's rooms and those typed by size
    val shown = ls.filter { it.roomId == null || it.roomId in names }
    if (shown.isEmpty()) return
    ensure(200f)
    h2(t("tl.r.title"))
    val rows = ArrayList<List<Cell>>()
    rows += listOf(th(t("tl.r.where")), th(t("tl.r.layout")), th(t("tl.r.tile")), th(t("tl.r.look")))
    shown.forEach { x ->
        rows += listOf(cell(x.roomId?.let { names[it] } ?: t("tl.r.typed")), cell(layoutLine(x)), cell(layoutTile(x)), cell(layoutLook(x)))
    }
    table(rows, head = 1)
    fn(t("tl.r.note"))
    typedPanels(shown.filter { it.roomId == null && it.panel != null })
    // each tiled room: the floor from above, then the tiled walls from the front
    sn.rooms.forEach { sr ->
        val r = sr.room
        val mine = ls.filter { it.roomId == r.id }
        if (mine.isEmpty()) return@forEach
        val g = roomGeo(r, sn.snap, troom.firstOrNull { it.roomId == r.id }?.fixes ?: emptyList()) ?: return@forEach
        val fl = floorLayout(ls, r.id)
        val laid = mine.map { it to layRoom(it, g, fl) }
        newPage()
        h2(t("tl.r.room", "r" to (names[r.id] ?: dn(r.name, l))))
        // the plan, fitted in the page's width
        val xs = g.floor.map { it.x }; val ys = g.floor.map { it.y }
        val x0 = xs.min(); val y0 = ys.min(); val bw = (xs.max() - x0).coerceAtLeast(1.0); val bh = (ys.max() - y0).coerceAtLeast(1.0)
        val ph = 250f; val pad = 16f
        val k = minOf((CW - 2 * pad) / bw, (ph - 2 * pad) / bh).toFloat()
        val ox = PX + (CW - bw.toFloat() * k) / 2
        space(0f)
        val top = y
        val oy = top + (ph - bh.toFloat() * k) / 2
        val plan = { v: V2 -> Offset(ox + ((v.x - x0) * k).toFloat(), oy + ((v.y - y0) * k).toFloat()) }
        draw {
            drawRect(Color.White, Offset(PX, top), Size(CW, ph))
            laid.forEach { (lt, ld) -> drawLaidCapped(ld, lt, { s -> if (s.kind == "floor") plan else { _ -> null } }, outline = true) }
            val path = Path().apply { g.floor.forEachIndexed { i, v -> val o = plan(v); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }; close() }
            drawPath(path, WALL_INK, style = Stroke(1.2f))
            drawRect(FRAME, Offset(PX + .5f, top + .5f), Size(CW - 1f, ph - 1f), style = Stroke(.75f))
        }
        // wall letters by each wall's middle, inside the plan
        val letters = g.walls.map { w -> w to measure(w.id, ui(8f, 700, WALL_INK)) }
        draw {
            letters.forEach { (w, m) ->
                val mid = w.at(w.len / 2, 9.0 / k.coerceAtLeast(.001f))
                val o = plan(mid)
                drawText(m, topLeft = Offset(o.x - m.size.width / 2f, o.y - m.size.height / 2f))
            }
        }
        y += ph; after(8f)
        // the walls with tiles on them, two a row (an inner partition's faces too, each as high as it is)
        val walls = (g.walls + g.inner).filter { w -> laid.any { (_, ld) -> ld.surfs.any { it.wall == w.id && it.kind != "floor" } } }
        val ew = (CW - 10f) / 2; val eh = 150f
        walls.chunked(2).forEach { two ->
            val caps = two.map { w -> measure(t("tl.wallN", "w" to w.id) + " · " + len(w.len.toInt()) + " " + mUnit(), ui(9f, 600)) }
            val need = caps.maxOf { it.size.height.toFloat() } + 3f + eh
            ensure(need + 6f); space(0f)
            val t0 = y
            draw {
                two.forEachIndexed { i, w ->
                    val x = PX + i * (ew + 10f)
                    drawText(caps[i], topLeft = Offset(x, t0))
                    val bt = t0 + caps[i].size.height + 3f
                    drawRect(Color.White, Offset(x, bt), Size(ew, eh))
                    val wh = (g.innerH[w.id] ?: g.H).toFloat()
                    val kk = minOf((ew - 20f) / w.len.toFloat().coerceAtLeast(1f), (eh - 20f) / g.H.toFloat().coerceAtLeast(1f))
                    val ex = x + (ew - w.len.toFloat() * kk) / 2; val eb = bt + eh - (eh - g.H.toFloat() * kk) / 2
                    val elev = { v: V2 -> Offset(ex + (v.x * kk).toFloat(), eb - (v.y * kk).toFloat()) }
                    // the wall's own surfaces: the wall less its openings, a bath's front, a niche's back, a column's face
                    val on = { s: uz.metrx.app.tiles.Surf -> s.wall == w.id && (s.kind == "wall" || s.kind == "bath" || s.kind == "niche" || (s.kind == "col" && s.key.endsWith(":f"))) }
                    laid.forEach { (lt, ld) -> drawLaidCapped(ld, lt, { s -> if (on(s)) elev else { _ -> null } }, outline = true) }
                    drawRect(WALL_INK, Offset(ex, eb - wh * kk), Size(w.len.toFloat() * kk, wh * kk), style = Stroke(1f))
                    // the doors and windows, outlined
                    r.openings.filter { it.wall == w.id }.forEach { o ->
                        drawRect(WALL_INK, Offset(ex + o.off * kk, eb - (o.sill + o.h) * kk), Size(o.w * kk, o.h * kk), style = Stroke(.8f))
                    }
                    drawRect(FRAME, Offset(x + .5f, bt + .5f), Size(ew - 1f, eh - 1f), style = Stroke(.75f))
                }
            }
            y += need; after(10f)
        }
    }
}

/**
 * The layouts typed by size (no room): each surface on its own, two a row, with its tiles and cuts as laid, like a
 * room's walls; a floor seen from above, a wall or backsplash from the front.
 */
private fun Doc.typedPanels(ls: List<TileLayout>) {
    val ew = (CW - 10f) / 2; val eh = 150f
    ls.chunked(2).forEach { two ->
        val caps = two.map { l -> val p = l.panel!!; measure(t(placeKey(l)) + " · " + len(p.a) + " × " + len(p.b) + " " + mUnit(), ui(9f, 600)) }
        val need = caps.maxOf { it.size.height.toFloat() } + 3f + eh
        ensure(need + 6f); space(8f)
        val t0 = y
        draw {
            two.forEachIndexed { i, l ->
                val p = l.panel!!
                val x = PX + i * (ew + 10f)
                drawText(caps[i], topLeft = Offset(x, t0))
                val bt = t0 + caps[i].size.height + 3f
                drawRect(Color.White, Offset(x, bt), Size(ew, eh))
                val a = p.a.toFloat().coerceAtLeast(1f); val b = p.b.toFloat().coerceAtLeast(1f)
                val kk = minOf((ew - 20f) / a, (eh - 20f) / b)
                val ex = x + (ew - a * kk) / 2; val ey = bt + (eh - b * kk) / 2
                val floor = p.kind == "floor"
                // a floor's second size runs down the page, a wall's up it
                val at = { v: V2 -> Offset(ex + (v.x * kk).toFloat(), if (floor) ey + (v.y * kk).toFloat() else ey + b * kk - (v.y * kk).toFloat()) }
                uz.metrx.app.tiles.panelSurf(l, uz.metrx.app.tiles.panelFrame(p.kind))?.let { s ->
                    drawLaidCapped(uz.metrx.app.tiles.layAll(l, listOf(s), null, null), l, { _ -> at }, outline = true)
                }
                drawRect(WALL_INK, Offset(ex, ey), Size(a * kk, b * kk), style = Stroke(1f))
                drawRect(FRAME, Offset(x + .5f, bt + .5f), Size(ew - 1f, eh - 1f), style = Stroke(.75f))
            }
        }
        y += need; after(10f)
    }
}
