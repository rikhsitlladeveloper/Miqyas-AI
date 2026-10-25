package uz.metrx.app.furniture

import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.min

/*
 * Board-built furniture that is not a cabinet (decided 22 Oct 2026): beds (plain on legs, drawers under, a lift-up
 * base over a storage box), bunk and loft beds, tables (dining, coffee), the bar counter, the hallway's mirror panel with
 * hooks, and the mirror over a dressing table. Each is one module with a few options ([Opt]); its boards ([itemBoards])
 * make both its parts and its 3D, so the cut list and the picture always agree. Pure Kotlin, unit-tested (ItemsTest).
 * The sizes and the construction are defaults for the founder's makers to check.
 */

/** The module types of these pieces (Module.type). */
val ITEM_MODS = setOf("bed", "bunk", "loft", "table", "bar", "hooks", "mirror")

/** The ladder of a bunk or loft bed stands this far out from the frame's front. */
const val LADDER_D = 60

/** A bed's mattress lies this far below the top of its frame (the frame holds it). */
const val BED_SINK = 60

/**
 * One board of a piece, or something only the 3D shows: its part ([key], strings fp.*; "" not a part) and [role]
 * (carcass, front; or for the picture only: top, mattress, lamel, metal, mirror, white); where it is, [a0]..[a1] across,
 * [y0]..[y1] up from the floor, [n0]..[n1] out from the back, mm. [lift]: it rises with a lift-up base; [round]: a
 * table top's corner radius.
 */
data class Board(val key: String, val role: String, val a0: Int, val a1: Int, val y0: Int, val y1: Int, val n0: Int, val n1: Int,
                 val lift: Boolean = false, val round: Int = 0)

/** A drawer under a bed: on its left ([side] -1) or right (+1) side, [n0]..[n1] along the bed, [y0]..[y1] up; its box [depth] deep. */
data class BedDrawer(val side: Int, val n0: Int, val n1: Int, val y0: Int, val y1: Int, val depth: Int)

/** A bed's drawers: two a side (one when short), both sides from a 1400 mattress, else the right one. */
fun bedDrawers(m: Module, ws: Workshop): List<BedDrawer> {
    val o = m.opt ?: return emptyList()
    if (m.type != "bed" || o.bed != "drawers") return emptyList()
    val t = ws.t
    val sides = if (o.mw >= 1400) listOf(-1, 1) else listOf(1)
    val n = if (o.ml >= 1800) 2 else 1
    val len = m.d - 2 * t
    val fw = (len - (n + 1) * 3) / n
    val y1 = m.h - 90 - 3
    val depth = if (sides.size == 2) m.w / 2 - t - t / 2 - 20 else m.w - 2 * t - 40
    return sides.flatMap { s -> (0 until n).map { i -> BedDrawer(s, t + 3 + i * (fw + 3), t + 3 + i * (fw + 3) + fw, 40, y1, depth) } }
}

/** A loft or bunk bed's upper platform (the top of its slats), mm from the floor. */
fun upperDeck(m: Module) = if (m.type == "loft") m.h - 450 else m.h - 500

/** The front of a bunk or loft bed's frame (its ladder stands in front of it). */
fun frameD(m: Module) = if (m.type == "bunk" || m.type == "loft") m.d - LADDER_D else m.d

/** A table's or bar counter's top: 38 of worktop board, or the front board (twice, glued, on a dining table or a bar). */
fun topT(m: Module, ws: Workshop): Int {
    val o = m.opt ?: Opt()
    return if (o.top == "wt") 38 else ws.t * (if (m.h >= 650) 2 else 1)
}

/** The boards of an item module, in its own frame (its back's left end at 0, 0, 0). */
fun itemBoards(m: Module, ws: Workshop): List<Board> {
    val t = ws.t; val o = m.opt ?: Opt()
    val W = m.w; val D = m.d; val H = m.h; val E = m.elev
    val out = ArrayList<Board>()
    when (m.type) {
        "bed" -> {
            val hb = max(o.hb, H + 100)
            val yb = if (o.bed == "legs") max(0, H - 260) else 0
            val yp = H - BED_SINK
            out += Board("fp.headboard", "front", 0, W, 0, hb, 0, t)
            out += Board("fp.footboard", "front", 0, W, yb, H, D - t, D)
            val dr = bedDrawers(m, ws)
            listOf(-1, 1).forEach { s ->
                val a0 = if (s < 0) 0 else W - t
                // over drawers the side is a strip along the top; else a whole board
                if (dr.any { it.side == s }) out += Board("fp.sideRail", "front", a0, a0 + t, H - 90, H, t, D - t)
                else out += Board("fp.bedSide", "front", a0, a0 + t, yb, H, t, D - t)
            }
            // a spine down the middle of a wide bed carries the slats (and parts the drawers or the box)
            if (o.mw >= 1400) out += Board("fp.spine", "carcass", W / 2 - t / 2, W / 2 + t - t / 2, yb, yp - 50, t, D - t)
            // the drawers run between cross boards; a one-sided row has a board behind it
            dr.groupBy { it.side }.forEach { (s, row) ->
                val a0 = if (s < 0) t else W - t - row[0].depth - 20
                row.zipWithNext().forEach { (a, _) ->
                    val c = a.n1 + 1
                    out += Board("fp.dCase", "carcass", a0, a0 + row[0].depth + 20, 0, yp - 50, c - t / 2, c + t - t / 2)
                }
            }
            if (dr.isNotEmpty() && o.mw < 1400) out += Board("fp.dBack", "carcass", W - t - dr[0].depth - 20 - t, W - t - dr[0].depth - 20, 0, yp - 50, t, D - t)
            if (o.bed == "lift") out += Board("fp.boxBottom", "carcass", t, W - t, 30, 30 + t, t, D - t)
            if (o.bed == "legs") {
                // metal legs at the foot and halfway along; the headboard stands on the floor
                val ns = listOf(D - t - 60, D / 2 - 20)
                ns.forEach { n -> listOf(t + 10, W - t - 50).forEach { a -> out += Board("", "metal", a, a + 40, 0, yb, n, n + 40) } }
                if (o.mw >= 1400) out += Board("", "metal", W / 2 - 20, W / 2 + 20, 0, yb, D / 2 - 20, D / 2 + 20)
            }
            // what the picture shows on it: the slats (they rise with a lift-up base), the mattress, pillows
            val lift = o.bed == "lift"
            out += Board("", "lamel", t + 4, W - t - 4, yp - 30, yp, t + 4, D - t - 4, lift = lift)
            out += Board("", "mattress", t + 6, W - t - 6, yp, yp + 200, t + 6, D - t - 6, lift = lift)
            val pw = if (o.mw >= 1200) (W - 2 * t - 60) / 2 else W - 2 * t - 60
            (if (o.mw >= 1200) listOf(0, 1) else listOf(0)).forEach { i ->
                val a0 = t + 20 + i * (pw + 20)
                out += Board("", "white", a0, a0 + pw, yp + 200, yp + 320, t + 40, t + 400, lift = lift)
            }
        }
        "bunk", "loft" -> {
            val fd = frameD(m)
            val yu = upperDeck(m)
            out += Board("fp.bedSide", "front", 0, t, 0, H, 0, fd)
            out += Board("fp.bedSide", "front", W - t, W, 0, H, 0, fd)
            // the upper level: a high guard along the wall, the front rail, and a guard over it but at the ladder
            out += Board("fp.guard", "front", t, W - t, yu - 120, H - 60, 0, t)
            out += Board("fp.bedRail", "front", t, W - t, yu - 120, yu + 150, fd - t, fd)
            val open = 550
            if (o.ladder == "R") out += Board("fp.guard", "front", t, W - t - open, yu + 150, yu + 330, fd - t, fd)
            else out += Board("fp.guard", "front", t + open, W - t, yu + 150, yu + 330, fd - t, fd)
            out += Board("", "lamel", t + 4, W - t - 4, yu - 30, yu, t + 4, fd - t - 4)
            out += Board("", "mattress", t + 6, W - t - 6, yu, yu + 180, t + 6, fd - t - 6)
            out += Board("", "white", t + (if (o.ladder == "R") 30 else W - 2 * t - 530), t + (if (o.ladder == "R") 530 else W - 2 * t - 30), yu + 180, yu + 290, t + 40, fd - t - 40)
            if (m.type == "bunk") {
                val yl = 300
                out += Board("fp.bedRail", "front", t, W - t, 120, yl + 150, 0, t)
                out += Board("fp.bedRail", "front", t, W - t, 120, yl + 150, fd - t, fd)
                out += Board("", "lamel", t + 4, W - t - 4, yl - 30, yl, t + 4, fd - t - 4)
                out += Board("", "mattress", t + 6, W - t - 6, yl, yl + 180, t + 6, fd - t - 6)
                out += Board("", "white", t + 30, t + 530, yl + 180, yl + 290, t + 40, fd - t - 40)
            } else out += Board("fp.bedRail", "front", t, W - t, 100, 250, 0, t)
            // the ladder at one end of the front: two stringers and its rungs
            val la0 = if (o.ladder == "R") W - t - 30 - 420 else t + 30
            val la1 = la0 + 420
            val top = yu + 330
            out += Board("fp.ladder", "front", la0, la0 + t, 0, top, fd, D)
            out += Board("fp.ladder", "front", la1 - t, la1, 0, top, fd, D)
            var y = 260
            while (y < yu - 40) { out += Board("fp.rung", "front", la0 + t, la1 - t, y, y + t, fd, D); y += 260 }
        }
        "table" -> {
            val tt = topT(m, ws)
            val wt = o.top == "wt"
            val r = if (o.round) min(120, min(W, D) / 4) else 0
            val key = if (o.round) "fp.topR" else "fp.top"
            if (wt) out += Board("", "top", 0, W, H - tt, H, 0, D, round = r)
            else (0 until tt / t).forEach { k -> out += Board(key, "front", 0, W, H - tt + k * t, H - tt + (k + 1) * t, 0, D, round = r) }
            val y1 = H - tt
            when (o.legs) {
                "metal4" -> {
                    // a frame of strips under the top, a straight metal leg in each corner
                    out += Board("fp.apron", "carcass", 70, W - 70, y1 - 80, y1, 70, 70 + t)
                    out += Board("fp.apron", "carcass", 70, W - 70, y1 - 80, y1, D - 70 - t, D - 70)
                    out += Board("fp.apron", "carcass", 70, 70 + t, y1 - 80, y1, 70 + t, D - 70 - t)
                    out += Board("fp.apron", "carcass", W - 70 - t, W - 70, y1 - 80, y1, 70 + t, D - 70 - t)
                    listOf(30, W - 70).forEach { a -> listOf(30, D - 70).forEach { n -> out += Board("", "metal", a, a + 40, 0, y1, n, n + 40) } }
                }
                "frame" -> listOf(50, W - 90).forEach { a ->
                    // a U of square tube at each end: two posts, the foot and the top bar
                    listOf(50, D - 90).forEach { n -> out += Board("", "metal", a, a + 40, 30, y1 - 30, n, n + 40) }
                    out += Board("", "metal", a, a + 40, 0, 30, 30, D - 30)
                    out += Board("", "metal", a, a + 40, y1 - 30, y1, 50, D - 50)
                }
                else -> {
                    out += Board("fp.tLeg", "front", 60, 60 + t, 0, y1, 50, D - 50)
                    out += Board("fp.tLeg", "front", W - 60 - t, W - 60, 0, y1, 50, D - 50)
                    // a dining table's legs are held by a board under the top; a coffee table's by a shelf low down
                    if (H >= 650) out += Board("fp.apron", "front", 60 + t, W - 60 - t, y1 - 150, y1, D / 2 - t / 2, D / 2 + t - t / 2)
                    else out += Board("fp.shelf", "front", 60 + t, W - 60 - t, 100, 100 + t, 50, D - 50)
                }
            }
        }
        "bar" -> {
            val tt = topT(m, ws)
            val db = max(250, D - o.over)
            val y1 = H - tt
            out += Board("fp.side", "front", 0, t, 0, y1, 0, db)
            out += Board("fp.side", "front", W - t, W, 0, y1, 0, db)
            out += Board("fp.barFront", "front", t, W - t, 0, y1, db - t, db)
            out += Board("fp.plinth", "carcass", t, W - t, 0, 60, 30, 30 + t)
            out += Board("fp.bottom", "carcass", t, W - t, 60, 60 + t, 0, db - t)
            val mid = W > 1200
            if (mid) out += Board("fp.divider", "carcass", W / 2 - t / 2, W / 2 + t - t / 2, 60 + t, y1, 0, db - t)
            if (o.shelves) (1..2).forEach { k ->
                val y = 60 + t + k * (y1 - 60 - t) / 3
                if (mid) { out += Board("fp.shelf", "carcass", t, W / 2 - t / 2, y, y + t, 20, db - t - 2); out += Board("fp.shelf", "carcass", W / 2 + t - t / 2, W - t, y, y + t, 20, db - t - 2) }
                else out += Board("fp.shelf", "carcass", t, W - t, y, y + t, 20, db - t - 2)
            }
            if (o.top == "wt") out += Board("", "top", 0, W, y1, H, 0, D)
            else (0 until tt / t).forEach { k -> out += Board("fp.top", "front", 0, W, y1 + k * t, y1 + (k + 1) * t, 0, D) }
            if (o.foot) {
                out += Board("", "metal", 40, W - 40, 230, 262, db + 110, db + 142)
                listOf(80, W - 112).forEach { a -> out += Board("", "metal", a, a + 32, 238, 254, db, db + 110) }
            }
        }
        "hooks" -> {
            out += Board("fp.panel", "front", 0, W, E, E + H, 0, t)
            var mirB = E + H
            val mirR = if (o.mirW > 0 && o.mirH > 0) {
                val mw = min(o.mirW, W - 160); val mh = min(o.mirH, H - 200)
                out += Board("", "mirror", 80, 80 + mw, E + H - 120 - mh, E + H - 120, t, t + 4)
                mirB = E + H - 120 - mh
                80 + mw
            } else 0
            // the hooks in a row beside the mirror, a little under the top; no room beside it: across the panel under it
            val n = o.hooks.coerceIn(0, 12)
            if (n > 0) {
                val beside = mirR + 100 + (if (n > 1) 40 * (n - 1) else 0) <= W - 80
                val a0 = if (beside) mirR + 100 else 80; val a1 = W - 80
                (0 until n).forEach { i ->
                    val a = if (n == 1) (a0 + a1) / 2 else a0 + (a1 - a0) * i / (n - 1)
                    val y = if (beside || mirR == 0) E + H - 260 else max(E + 80, mirB - 100)
                    out += Board("", "metal", a - 8, a + 8, y - 60, y + 10, t, t + 60)
                }
            }
            if (o.shelf) {
                out += Board("fp.shelf", "front", 0, W, E + H, E + H + t, 0, 250)
                listOf(60, W - 76).forEach { a -> out += Board("", "metal", a, a + 16, E + H - 120, E + H, t, 200) }
            }
        }
        "mirror" -> out += Board("", "mirror", 0, W, E, E + H, 0, 5)
    }
    return out
}

/** The parts of an item module: its boards, each by its two larger sizes (seen boards banded all round), and a bed's drawers. */
fun itemParts(m: Module, ws: Workshop): List<FPart> {
    val id = m.label.ifEmpty { m.id }
    val out = ArrayList<FPart>()
    itemBoards(m, ws).filter { it.key.isNotEmpty() && (it.role == "carcass" || it.role == "front") }.forEach { b ->
        val s = listOf(b.a1 - b.a0, b.y1 - b.y0, b.n1 - b.n0).sortedDescending()
        out += if (b.role == "front") part(b.key, id, "front", s[0], s[1], 1, ALL, ALL) else part(b.key, id, "carcass", s[0], s[1], 1, THICK)
    }
    bedDrawers(m, ws).forEach { d ->
        out += part("fp.dFace", id, "front", d.n1 - d.n0, d.y1 - d.y0, 1, ALL, ALL, grain = true)
        out += drawerBox(id, d.n1 - d.n0, d.depth, d.y1 - d.y0, ws.t)
    }
    return out.groupBy { it.copy(qty = 0) }.map { (k, v) -> k.copy(qty = v.sumOf { it.qty }) }
}

/** An item module's hardware. */
fun itemHardware(m: Module, ws: Workshop, add: (String, Int) -> Unit) {
    val o = m.opt ?: Opt()
    when (m.type) {
        "bed" -> {
            add("confirmat", if (o.mw >= 1400) 24 else 16)
            when (o.bed) {
                "lift" -> add("bedLift", 1)
                else -> add("bedBase", 1)
            }
            if (o.bed == "legs") add("leg", 4 + if (o.mw >= 1400) 1 else 0)
            bedDrawers(m, ws).let { ds -> add("runner", ds.size); ds.indices.forEach { add(if (hasHandle(m, "bd$it")) "handle" else "push", 1) } }
        }
        "bunk" -> { add("bedBase", 2); add("confirmat", 36) }
        "loft" -> { add("bedBase", 1); add("confirmat", 28) }
        "table" -> {
            add("confirmat", 8)
            when (o.legs) { "metal4" -> add("tableLeg", 4); "frame" -> add("tableFrame", 1) }
        }
        "bar" -> {
            add("confirmat", 20)
            if (o.shelves) add("pin", 4 * (if (m.w > 1200) 4 else 2))
            if (o.foot) add("barRail", m.w - 80)
        }
        "hooks" -> {
            add("hanger", 2); add("hook", o.hooks.coerceIn(0, 12))
            if (o.mirW > 0 && o.mirH > 0) { add("mirror", min(o.mirW, m.w - 160) * min(o.mirH, m.h - 200)); add("clip", 4) }
            if (o.shelf) add("confirmat", 4)
        }
        "mirror" -> { add("mirror", m.w * m.h); add("clip", 4) }
    }
}

/** Worktop board a table or bar counter's top takes, running mm (bought by the metre like a kitchen's). */
fun itemWorktopMm(m: Module): Int = if ((m.type == "table" || m.type == "bar") && m.opt?.top == "wt") m.w else 0

/** How high an item reaches: a bed's headboard, a mirror panel's hat shelf. */
fun itemTop(m: Module, ws: Workshop): Int = m.elev + when (m.type) {
    "bed" -> max(m.h, m.opt?.hb ?: 0)
    "hooks" -> m.h + if (m.opt?.shelf == true) ws.t else 0
    else -> m.h
}

/** The module's outer size from its options: a bed round its mattress, a bunk or loft bed along it, a mirror panel's depth. */
fun itemSized(m: Module, ws: Workshop): Module {
    val o = m.opt ?: return m
    val t = ws.t
    return when (m.type) {
        "bed" -> m.copy(w = o.mw + 2 * t + 10, d = o.ml + 2 * t + 10)
        "bunk", "loft" -> m.copy(w = o.ml + 2 * t + 10, d = o.mw + 2 * t + 10 + LADDER_D)
        "hooks" -> m.copy(d = if (o.shelf) 250 else t + 60)
        else -> m
    }
}

/** A new item module of [type] on [wall] at [x]: [w] × [h] × [d] where they are its own (tables, the bar, panels), [o] its options. */
fun itemModule(type: String, ws: Workshop, wall: String, x: Int, w: Int, h: Int, d: Int, o: Opt, elev: Int = 0): Module =
    itemSized(Module(uid(), type, w, h, d, x = x, wall = wall, elev = elev, fronts = Fronts("open", 0), legs = false, base = 0, opt = o), ws)

/** The usual ranges of an item's sizes in its designer, mm. */
fun itemRange(m: Module, key: String): IntRange = when (key) {
    "mw" -> if (m.type == "bed") 700..2000 else 700..1000
    "ml" -> if (m.type == "bed") 1800..2200 else 1600..2100
    "hb" -> 600..1600
    "over" -> 150..450
    "mirW", "mirH" -> 0..2000
    "e" -> 0..2200
    "h" -> when (m.type) { "bed" -> 250..700; "bunk", "loft" -> 1400..2200; "table" -> 300..900; "bar" -> 900..1250; "hooks" -> 600..2200; else -> 300..2200 }
    "d" -> when (m.type) { "table" -> 300..1200; "bar" -> 400..900; else -> 5..1000 }
    else -> when (m.type) { "table", "bar" -> 400..3000; else -> 300..2400 }
}

/** An item module with one size changed (and its outer size following). */
fun itemSet(m: Module, key: String, v: Int, ws: Workshop): Module {
    val o = m.opt ?: Opt()
    val n = when (key) {
        "w" -> m.copy(w = v)
        "h" -> m.copy(h = v)
        "d" -> m.copy(d = v)
        "e" -> m.copy(elev = v)
        "mw" -> m.copy(opt = o.copy(mw = v))
        "ml" -> m.copy(opt = o.copy(ml = v))
        "hb" -> m.copy(opt = o.copy(hb = v))
        "over" -> m.copy(opt = o.copy(over = v))
        "mirW" -> m.copy(opt = o.copy(mirW = v))
        "mirH" -> m.copy(opt = o.copy(mirH = v))
        "hooks" -> m.copy(opt = o.copy(hooks = v))
        else -> m
    }
    return itemSized(n, ws)
}

/** What a size of an item module is now (the designer's rows). */
fun itemGet(m: Module, key: String): Int {
    val o = m.opt ?: Opt()
    return when (key) {
        "w" -> m.w; "h" -> m.h; "d" -> m.d; "e" -> m.elev
        "mw" -> o.mw; "ml" -> o.ml; "hb" -> o.hb; "over" -> o.over; "mirW" -> o.mirW; "mirH" -> o.mirH; "hooks" -> o.hooks
        else -> 0
    }
}
