package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.core.shortMoney
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.FCheck
import uz.metrx.app.furniture.FModelDef
import uz.metrx.app.furniture.FitIssue
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.NO_HANDLES
import uz.metrx.app.furniture.OrderIssue
import uz.metrx.app.furniture.Remnant
import uz.metrx.app.furniture.SizeStep
import uz.metrx.app.furniture.commonFront
import uz.metrx.app.furniture.commonHandle
import uz.metrx.app.furniture.orderChecks
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.furniture.remnantsFor
import uz.metrx.app.furniture.shapeLeft
import uz.metrx.app.furniture.shapeOpen
import uz.metrx.app.furniture.swapAll
import uz.metrx.app.furniture.usualHw
import uz.metrx.app.furniture.wsOf
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Ideas taken from Bazis Mebelshchik, kept simple for a phone (23 Oct 2026, memory bazis-ideas): a corner piece's shape
 * as pictures and whichever sides were measured; "Change for all" fronts and handles; one Check list before sending;
 * the live price in the designers; the workshop's remnants. The rules are in furniture/ (Checks, Swap, Remnants,
 * Labels, Steps).
 */

/* ---------------- a corner piece's shape and measured sides, as pictures ---------------- */

/** A choice drawn as small top-down pictures: a corner piece's shapes, or which of its sides were measured ([sh] its shape). */
@Composable
internal fun PicsAsk(m: FModelDef, s: SizeStep, cur: Int, sh: Int, onPick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr(s.label), style = ui(21f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        Text(tr(s.help), style = ui(13f, 400, G.ink2, 1.4f))
        s.opts.indices.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { i ->
                    val on = i == cur
                    val shape = RoundedCornerShape(18.dp)
                    val name = tr(s.opts[i])
                    Column(Modifier.weight(1f).fillMaxHeight().clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
                        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape).semantics { selected = on; contentDescription = name }
                        .clickable(role = Role.RadioButton) { onPick(i) }.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Canvas(Modifier.fillMaxWidth().aspectRatio(1.25f).clip(RoundedCornerShape(12.dp)).background(Color(0xFFF6F8FC))) {
                            if (s.key == "sh") cornerPic(m, i, -1) else cornerPic(m, sh, i)
                        }
                        Text(name, style = ui(14f, 700, if (on) G.cobalt2 else G.ink, 1.25f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Text(tr("${s.opts[i]}.s"), style = ui(12f, 400, G.ink2, 1.3f), maxLines = 3, overflow = TextOverflow.Ellipsis)
                    }
                }
                if (row.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}

private val P_WALL = Color(0xFF9AA8BF)
private val P_PIECE = Color(0xFFDDE6F5)
private val P_EDGE = Color(0xFF3E4A61)
private val P_BLUE = Color(0xFF3550E0)

/**
 * A corner piece from above, its main wall at the top: shape [sh] (its corner on the right or left, the corner
 * wardrobe's door or open shelves); [ms] ≥ 0 marks in blue the sides measured that way (arms along the walls, the
 * fronts, the walls themselves).
 */
private fun DrawScope.cornerPic(m: FModelDef, sh: Int, ms: Int) {
    val w = size.width; val h = size.height
    val left = shapeLeft(m.type, sh)
    val kitchen = m.kind == "kitchen"
    val desk = m.type == "cornerDesk"
    val pad = w * .1f
    val wallT = w * .03f
    val depth = h * (if (kitchen) .2f else .24f)
    // drawn as a right-hand L, mirrored for a left one
    fun x(v: Float) = if (left) w - v else v
    fun rect(x0: Float, y0: Float, x1: Float, y1: Float, c: Color, stroke: Boolean = false, sw: Float = 1.5f) {
        val a = minOf(x(x0), x(x1)); val b = maxOf(x(x0), x(x1))
        if (stroke) drawRect(c, Offset(a, y0), Size(b - a, y1 - y0), style = Stroke(sw)) else drawRect(c, Offset(a, y0), Size(b - a, y1 - y0))
    }
    fun line(x0: Float, y0: Float, x1: Float, y1: Float, c: Color, sw: Float, dash: Boolean = false) =
        drawLine(c, Offset(x(x0), y0), Offset(x(x1), y1), sw, StrokeCap.Round, if (dash) PathEffect.dashPathEffect(floatArrayOf(6f, 5f)) else null)
    val top = pad; val cornerX = w - pad
    // the walls: the main one along the top, the side one down the right
    rect(pad * .4f, top - wallT, cornerX + wallT, top, P_WALL)
    rect(cornerX, top - wallT, cornerX + wallT, h - pad * .4f, P_WALL)
    // the arms: along the main wall from its free end to the corner, down the side wall from past the first's depth
    val a0 = pad * 1.3f; val bEnd = h - pad * 1.2f
    // as the engine builds it: on the right the main arm runs into the corner, on the left the side arm does (the
    // made-up walls D, A: the left wall's arm ends in the corner, the back wall's starts past its depth)
    if (!left) {
        rect(a0, top, cornerX, top + depth, P_PIECE); rect(a0, top, cornerX, top + depth, P_EDGE, true)
        rect(cornerX - depth, top + depth, cornerX, bEnd, P_PIECE); rect(cornerX - depth, top + depth, cornerX, bEnd, P_EDGE, true)
    } else {
        rect(a0, top, cornerX - depth, top + depth, P_PIECE); rect(a0, top, cornerX - depth, top + depth, P_EDGE, true)
        rect(cornerX - depth, top, cornerX, bEnd, P_PIECE); rect(cornerX - depth, top, cornerX, bEnd, P_EDGE, true)
    }
    val sw = 2.2f * density
    val dash = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))
    when {
        kitchen -> {
            // the sink on the first run, the hob on the next (an L with its corner on the left starts on the side wall)
            val sx = a0 + (cornerX - depth - a0) * .45f
            val hy = top + depth + (bEnd - top - depth) * .5f
            fun sink(x0: Float, y0: Float, x1: Float, y1: Float) { rect(x0, y0, x1, y1, Color.White); rect(x0, y0, x1, y1, P_EDGE, true, 1.2f) }
            fun hob(cx: Float, cy: Float) = listOf(-.22f, .22f).forEach { dy -> listOf(-.2f, .2f).forEach { dx ->
                drawCircle(P_EDGE, depth * .12f, Offset(x(cx + dx * depth), cy + dy * depth * 1.4f), style = Stroke(1.2f)) } }
            if (!left) { sink(sx, top + depth * .25f, sx + depth * .9f, top + depth * .8f); hob(cornerX - depth / 2, hy) }
            else { sink(cornerX - depth * .8f, hy - depth * .45f, cornerX - depth * .2f, hy + depth * .45f); hob(sx + depth * .45f, top + depth / 2) }
        }
        desk -> {
            // the chair in the inner corner
            drawCircle(P_EDGE, depth * .34f, Offset(x(cornerX - depth * 1.75f), top + depth * 1.75f), style = Stroke(1.4f))
        }
        // the corner unit: on the main arm at the corner (right), on the side arm at the corner (left)
        shapeOpen(m.type, sh) -> {
            // open shelves: their edges seen from above
            for (k in 1..3) {
                if (!left) line(cornerX - depth * 2.3f, top + depth * (.25f * k), cornerX - depth - 3f, top + depth * (.25f * k), P_EDGE, 1f)
                else line(cornerX - depth * (.25f * k), top + depth + 3f, cornerX - depth * (.25f * k), top + depth * 2.3f, P_EDGE, 1f)
            }
        }
        else -> {
            // the corner door and its swing, from shut (along the opening) to open (into the room), about the hinge
            val r = depth * 1.3f
            val hx = cornerX - depth * (if (left) 1f else 2.3f); val hy = top + depth
            if (!left) line(hx, hy, hx, hy + r, P_EDGE, 1.2f, true) else line(hx, hy, hx - r, hy, P_EDGE, 1.2f, true)
            drawArc(P_EDGE, 0f, 90f, false, Offset(x(hx) - r, hy - r), Size(2 * r, 2 * r), style = Stroke(1f, pathEffect = dash))
        }
    }
    // the measured sides
    when (measureOf(m, ms)) {
        "out", "kWall" -> { line(a0, top + sw, cornerX, top + sw, P_BLUE, sw); line(cornerX - sw, top, cornerX - sw, bEnd, P_BLUE, sw) }
        "in", "kIn" -> { line(a0, top + depth, cornerX - depth, top + depth, P_BLUE, sw); line(cornerX - depth, top + depth, cornerX - depth, bEnd, P_BLUE, sw) }
        "wall" -> { line(pad * .4f, top - wallT - sw, cornerX + wallT, top - wallT - sw, P_BLUE, sw); line(cornerX + wallT + sw, top - wallT, cornerX + wallT + sw, h - pad * .4f, P_BLUE, sw) }
    }
}

/** The way of measuring [ms] of a corner piece ("out", "in", "wall", a kitchen's "kWall", "kIn"), or "" for a shape picture. */
private fun measureOf(m: FModelDef, ms: Int): String =
    if (ms < 0) "" else uz.metrx.app.furniture.measuresOf(m).getOrNull(ms)?.removePrefix("bz.ms.") ?: ""

/** On the summary: the sides worked out from the ones typed, each marked as such (red when out of what the piece can be). */
@Composable
internal fun DerivedCard(derived: List<Triple<String, String, Boolean>>) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.blueWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("bz.derived"), style = ui(13.5f, 800, G.cobalt2))
        derived.forEach { (label, v, bad) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(label, style = ui(13.5f, 500, if (bad) G.err else G.ink), modifier = Modifier.weight(1f))
                Text(v, style = num(15f, 700, if (bad) G.err else G.ink))
                Text(tr("bz.calc"), style = ui(11.5f, 700, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(G.glass(.8f)).padding(horizontal = 6.dp, vertical = 2.dp))
            }
        }
        if (derived.any { it.third }) Text(tr("bz.derivedBad"), style = ui(12.5f, 600, G.err, 1.35f))
    }
}

/* ---------------- the live price in the designers (Advanced) ---------------- */

/** A slim bar under a designer: what this piece costs the customer now, and the workshop; it follows every change. */
@Composable
internal fun LivePrice(p: Project, f: Furniture) {
    val app = LocalApp.current
    val s = app.settings
    if (!s.advanced || f.modules.isEmpty()) return
    val lang = LocalLang.current; val en = lang == Lang.EN
    // a fixed order price has no price a piece: the piece by the margin
    val fp = p.fprice.let { if (it.mode == "fixed") it.copy(mode = "margin") else it }
    val pr = remember(f, fp, s.workshop, s.mats, s.hws) { priceOf(listOf(f), fp, s.workshop, s.mats, s.hws) }
    val price = pr.lines.firstOrNull { it.key == f.id }?.amount ?: pr.price
    // the piece's own cost: no installation or delivery (those are the order's, once)
    val cost = remember(f, s.workshop, s.mats, s.hws) { uz.metrx.app.furniture.costOf(listOf(f), wsOf(f, s.workshop), s.mats, s.hws, order = false).total }
    val mln = tr("pl.mln")
    fun short(v: java.math.BigInteger) = shortMoney(p, v, en, mln).let { it.first + " " + (it.second ?: curSuffix(p.currency, lang)) }
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 8.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xFF0E1C36))
        .clickable(role = Role.Button) { app.push(Route.Project(p.id, tab = "price")) }.padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        MIcon("coin", Color(0xFFB7C3D9), 18.dp, 2f)
        Text(tr("bz.live"), style = ui(12.5f, 500, Color(0xFFB7C3D9)), modifier = Modifier.weight(1f), maxLines = 1)
        Text(short(price), style = num(16f, 800, Color.White), maxLines = 1)
        Text(tr("bz.liveCost", "v" to short(cost)), style = ui(11.5f, 500, Color(0xFFB7C3D9)), maxLines = 1)
    }
}

/* ---------------- the one Check list ---------------- */

/** Every problem of the order's pieces: the board rules, how each fits its room, doors that hit, the designers' checks. */
internal fun orderIssues(app: App, p: Project): List<OrderIssue> {
    val s = app.settings
    val ws = s.workshop; val snap = s.angleSnap
    return orderChecks(p.furniture, ws, s.mats) { f ->
        val out = ArrayList<OrderIssue>()
        val room = roomOf(p, f) ?: return@orderChecks out
        val fws = wsOf(f, ws)
        val len = { id: String -> if (f.roomId == null) uz.metrx.app.furniture.freeLen(f, id) ?: wallLen(room, snap, id) else wallLen(room, snap, id) }
        val roomH = room.dim("H").v
        if (f.roomId != null) {
            // how it fits its walls (kept although too big: still said), and what it is in the way of
            uz.metrx.app.furniture.fitIssues(f, f.walls, len, roomH, ws, off = if (f.kind == "wardrobe") uz.metrx.app.furniture.runStart(f) else null)
                .forEach { out += OrderIssue(f.id, "err", it.key, it.vars) }
            val pw = uz.metrx.app.furniture.planWalls(room, snap)
            uz.metrx.app.furniture.placeWarnings(f, p.furniture.filter { it.roomId == room.id && it.id != f.id }, room, pw, ws)
                .forEach { out += OrderIssue(f.id, if (it.key == "fz.doorsHit" || it.key == "fz.hitPiece") "err" else "warn", it.key, it.vars) }
        }
        // the designers' own checks (the board rules and the fit are said above)
        val skip = setOf("wc.sheet", "wc.shelfWide", "wc.wide", "wc.high")
        val found = if (f.kind == "kitchen") uz.metrx.app.furniture.checks(f, kRuns(f, room, snap), fws, room.openings, room.points)
            else f.modules.filter { it.type == "wardrobe" }.flatMap { m ->
                uz.metrx.app.furniture.wardrobeChecks(m, if (f.roomId != null) m.wall?.let(len) else null, if (f.roomId != null) roomH else null, fws, room.openings, room.points) }
        found.filter { (it.level == "err" || it.level == "warn") && it.key !in skip }.forEach { out += OrderIssue(f.id, it.level, it.key, it.vars, it.mid) }
        out
    }
}

/** A problem in words: the board rules', a fit issue's (Free.kt, Placing.kt) or a designer check's. */
@Composable
internal fun orderIssueText(app: App, i: OrderIssue, f: Furniture): String {
    val lang = LocalLang.current
    val m = i.mid?.let { id -> f.modules.firstOrNull { it.id == id } }
    return when {
        i.key.startsWith("bz.ck.") -> {
            val v = LinkedHashMap<String, Any?>(i.vars)
            (i.vars["p"] as? String)?.let { v["p"] = tr(it) }
            val sec = if ((m?.sections?.size ?: 0) > 1) tr("bz.secN", "n" to i.vars["s"]) else null
            v["m"] = when {
                m == null -> dn(f.name, lang)
                // a piece of several boxes names the box; one box, its section (or the piece itself)
                m.type == "wardrobe" && uz.metrx.app.furniture.boxes(f).size > 1 -> tr(uz.metrx.app.furniture.boxRole(f, m)) + (sec?.let { ", $it" } ?: "")
                m.type == "wardrobe" -> sec ?: dn(f.name, lang)
                else -> modName(m)
            }
            tr(i.key, *v.toList().toTypedArray())
        }
        i.key.startsWith("fz.") -> issueText(app, FitIssue(i.key, i.vars), lang)
        else -> checkText(FCheck(i.level, i.key, i.vars, i.mid), f)
    }
}

/** Opens the piece of problem [i] where it can be put right: its module picked, a wardrobe's section's inside. */
internal fun App.openIssue(p: Project, i: OrderIssue) {
    val f = p.furniture.firstOrNull { it.id == i.fid } ?: return
    kit.sel = i.mid
    val sec = (i.vars["s"] as? Int)?.minus(1)?.coerceAtLeast(0) ?: 0
    push(when {
        f.kind == "kitchen" -> Route.Kitchen(p.id, f.id, wall = i.mid?.let { id -> f.modules.firstOrNull { it.id == id }?.wall })
        i.key == "bz.ck.shelf" || i.key == "bz.ck.drawer" -> Route.Wardrobe(p.id, f.id, step = 4, sec = sec)
        else -> Route.Wardrobe(p.id, f.id)
    })
    kit.tick++
}

/** On the order's Rooms tab: how many problems the Check list has (or that all is well), a tap opens it. */
@Composable
internal fun CheckCard(p: Project) {
    val app = LocalApp.current
    val s = app.settings
    if (p.furniture.none { it.modules.isNotEmpty() }) return
    val issues = remember(p.furniture, p.rooms, s.workshop, s.mats, s.angleSnap) { orderIssues(app, p) }
    val errs = issues.count { it.level == "err" }
    val good = Color(0xFF15803D)
    val (bg, fg) = when { errs > 0 -> G.errWash to G.err; issues.isNotEmpty() -> G.amberWash to G.amberInk; else -> G.greenWash to good }
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(18.dp)).background(bg).clickable(role = Role.Button) { app.push(Route.FCheck(p.id)) }
        .padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        MIcon(if (issues.isEmpty()) "check" else "alert", fg, 20.dp, 2.2f)
        Column(Modifier.weight(1f)) {
            Text(tr("bz.check"), style = ui(15f, 800, fg))
            Text(if (issues.isEmpty()) tr("bz.checkOk") else tr("bz.checkN", "n" to issues.size), style = ui(12.5f, 500, fg, 1.3f))
        }
        MIcon("chev", fg, 16.dp, 2f)
    }
}

/** The order's one Check list: every piece's problems, each opening its piece; then sending the design. */
@Composable
fun CheckScreen(rt: Route.FCheck) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val p = app.store.get(rt.pid) ?: return
    val issues = remember(p.furniture, p.rooms, s.workshop, s.mats, s.angleSnap) { orderIssues(app, p) }
    FPage(dn(p.name, lang), tr("bz.check"), { app.pop() }, footer = {
        GBtn(tr(if (issues.any { it.level == "err" }) "bz.sendAnyway" else "ns.shareB"), { app.push(Route.Report(p.id)) },
            if (issues.any { it.level == "err" }) Btn.SECONDARY else Btn.PRIMARY, icon = "share")
    }) {
        Text(tr("bz.checkB", "v" to uz.metrx.app.furniture.shelfSpanMax(s.workshop.t), "t" to s.workshop.t), style = ui(13f, 400, G.ink2, 1.4f))
        if (issues.isEmpty()) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.greenWash).padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MIcon("check", Color(0xFF15803D), 20.dp, 2.4f); Text(tr("bz.checkOkL"), style = ui(14f, 600, Color(0xFF15803D), 1.4f))
        }
        p.furniture.filter { f -> issues.any { it.fid == f.id } }.forEach { f ->
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(dn(f.name, lang), style = ui(15.5f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                issues.filter { it.fid == f.id }.forEach { i ->
                    val err = i.level == "err"
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(if (err) G.errWash else G.amberWash)
                        .clickable(role = Role.Button) { app.openIssue(p, i) }.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MIcon("alert", if (err) G.err else G.amberInk, 18.dp, 2f)
                        Text(orderIssueText(app, i, f), style = ui(13.5f, 500, if (err) G.err else G.amberInk, 1.35f), modifier = Modifier.weight(1f))
                        MIcon("chev", if (err) G.err else G.amberInk, 14.dp, 2f)
                    }
                }
            }
        }
    }
}

/* ---------------- Change for all: fronts and handles ---------------- */

@Composable
fun BazisSheet(s: Sheet): Boolean = when (s) {
    is Sheet.FSwap -> { SwapSheet(s.pid); true }
    else -> false
}

/** The fronts' board and the handles of every piece of the order, in one tap each; Undo puts them back. */
@Composable
private fun SwapSheet(pid: String) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val st = app.settings
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    fun apply(say: String, v: Pair<String, Any?>, fn: (List<Furniture>) -> List<Furniture>) {
        val before = p.furniture
        app.store.update(pid) { it.copy(furniture = fn(it.furniture)) }
        before.forEach { app.kit.forget(it.id) }; app.kit.tick++
        app.say(say, "n" to fs.size, v, action = "common.undo") {
            app.store.update(pid) { it.copy(furniture = before) }; app.kit.tick++
        }
    }
    GlassSheet(tr("bz.swap"), { app.sheet = null }) {
        Text(tr("bz.swapB", "n" to fs.size), style = ui(13f, 400, G.ink2, 1.4f))
        Text(tr("bz.front"), style = ui(15f, 800))
        val cur = commonFront(fs)
        st.mats.filter { it.kind == "board" }.forEach { mt ->
            val on = mt.id == cur
            val name = presetMatName(mt)
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.7f))
                .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, RoundedCornerShape(14.dp)).semantics { selected = on }
                .clickable(role = Role.RadioButton) { if (!on) apply("bz.swapFront", "m" to name) { swapAll(it, front = mt.id) } }.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(26.dp).clip(RoundedCornerShape(7.dp)).background(runCatching { Color(android.graphics.Color.parseColor(mt.rgb)) }.getOrDefault(Color.LightGray))
                    .border(1.dp, G.rim, RoundedCornerShape(7.dp)))
                Text(name, style = ui(14.5f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (on) MIcon("check", G.cobalt, 18.dp, 2.4f)
            }
        }
        Hairline()
        Text(tr("bz.handle"), style = ui(15f, 800))
        val ch = commonHandle(fs)
        val usual = usualHw(st.hws, "handle")
        // the usual handle, the others of the list, and none (push to open)
        val opts = listOfNotNull(usual?.let { "" to presetHwName(it) }) + st.hws.filter { it.kind == "handle" && it.id != usual?.id }.map { it.id to presetHwName(it) } + listOf(NO_HANDLES to tr("bz.noHandle"))
        opts.forEach { (id, name) ->
            val on = ch == id || (id == "" && ch == usual?.id)
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.7f))
                .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, RoundedCornerShape(14.dp)).semantics { selected = on }
                .clickable(role = Role.RadioButton) { if (!on) apply("bz.swapHandle", "m" to name) { swapAll(it, handle = id) } }.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Canvas(Modifier.size(26.dp)) {
                    val l = when (id) { NO_HANDLES -> 0f; "handleKnob" -> .18f; "handleLong" -> .9f; else -> .5f } * size.width
                    drawRoundRect(G.ink2, Offset(size.width * .2f, 0f), Size(size.width * .6f, size.height), style = Stroke(1.5f))
                    if (l > 0) drawLine(G.ink, Offset(size.width * .66f, (size.height - l) / 2), Offset(size.width * .66f, (size.height + l) / 2), 3f, StrokeCap.Round)
                }
                Text(name, style = ui(14.5f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (on) MIcon("check", G.cobalt, 18.dp, 2.4f)
            }
        }
    }
}

/** A board's name: a preset's in the app language (the workshop's own as typed). */
@Composable
private fun presetMatName(m: uz.metrx.app.furniture.Mat): String =
    if (uz.metrx.app.furniture.MAT_PRESETS.any { it.id == m.id && it.name == m.name } && uz.metrx.app.core.Strings.has("mp.${m.id}")) tr("mp.${m.id}") else m.name

/** A hardware item's name: a preset's in the app language. */
@Composable
private fun presetHwName(h: uz.metrx.app.furniture.Hw): String =
    if (uz.metrx.app.furniture.HW_PRESETS.any { it.id == h.id && it.name == h.name } && uz.metrx.app.core.Strings.has("hp.${h.id}")) tr("hp.${h.id}") else h.name

/* ---------------- remnants (Advanced) ---------------- */

/** The remnants order [p]'s cut list uses first (none in the simple app). */
fun remsOf(app: App, p: Project): List<Remnant> =
    if (!app.settings.advanced) emptyList() else remnantsFor(app.settings.remnants, p.id, p.cutAt > 0)

/** The workshop's remnants: by material, their sizes and where they came from; each can be thrown away. */
@Composable
fun RemnantsScreen() {
    val app = LocalApp.current
    if (!app.settings.advanced) { LaunchedEffect(Unit) { app.dropAdvanced() }; return }
    val lang = LocalLang.current
    val s = app.settings
    val all = s.remnants
    FPage(tr("wk.title"), tr("bz.remList"), { app.pop() }) {
        Text(tr("bz.remB", "v" to s.workshop.remMin), style = ui(13f, 400, G.ink2, 1.4f))
        if (all.isEmpty()) Text(tr("bz.remNone"), style = ui(14f, 500, G.ink2, 1.45f), modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(20.dp))
        all.groupBy { it.mat }.forEach { (mat, list) ->
            val m = s.mats.firstOrNull { it.id == mat }
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text((m?.let { presetMatName(it) } ?: mat) + " · ${list.size}", style = ui(15f, 800))
                list.sortedByDescending { it.L.toLong() * it.W }.forEach { r ->
                    val taken = !uz.metrx.app.furniture.removable(r)
                    Hairline()
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Column(Modifier.weight(1f)) {
                            Text("${r.L} × ${r.W} " + tr("u.mm") + if (r.grain) " ↕" else "", style = num(15f, 700))
                            val from = app.store.get(r.src)?.let { dn(it.name, lang) }
                            val by = r.used.takeIf { taken }?.let { app.store.get(it) }?.let { dn(it.name, lang) }
                            Text(listOfNotNull(from?.let { tr("bz.remFrom", "o" to it) }, if (!taken) tr("bz.remFree") else by?.let { tr("bz.remBy", "o" to it) } ?: tr("bz.remTaken")).joinToString(" · "),
                                style = ui(12f, 400, if (taken) G.amberInk else G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                        // a remnant a cut order took is locked: that board was cut, it is not in the store any more
                        if (taken) Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button) { app.say("bz.remLocked", kind = uz.metrx.app.ui.components.ToastKind.INFO) }
                            .semantics { contentDescription = app.t("bz.remLocked") }, contentAlignment = Alignment.Center) { MIcon("lock", G.ink3, 20.dp, 2f) }
                        else Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button) {
                            val before = s.remnants
                            s.setRemnantList(before.filter { it.id != r.id })
                            app.say("bz.remDeleted", action = "common.undo") { s.setRemnantList(before) }
                        }.semantics { contentDescription = app.t("common.delete") }, contentAlignment = Alignment.Center) { MIcon("trash", G.err, 20.dp, 2f) }
                    }
                }
            }
        }
    }
}

/** On the parts screen: the remnants this cut list uses, and saying it was cut (its offcuts kept); Undo. */
@Composable
internal fun RemnantCard(p: Project, cost: uz.metrx.app.furniture.Cost) {
    val app = LocalApp.current
    val s = app.settings
    val lang = LocalLang.current
    val used = cost.layouts.sumOf { it.rems.size }
    val kept = cost.layouts.flatMap { l -> (l.sheets + l.rems).flatMap { it.rest } }.count { (a, b) -> a >= s.workshop.remMin && b >= s.workshop.remMin }
    val time = java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM, java.util.Locale.forLanguageTag(lang.code)).format(java.util.Date(p.cutAt))
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tr("bz.rem"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(tr("bz.remN", "n" to s.remnants.count { it.used.isEmpty() }), style = ui(12.5f, 700, G.cobalt2),
                modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.push(Route.Remnants) }.padding(6.dp))
        }
        Text(if (used > 0) tr("bz.remUsed", "n" to used) else tr("bz.remUsed0"), style = ui(13f, 500, G.ink2, 1.4f))
        if (p.cutAt == 0L) {
            Text(tr("bz.remWill", "n" to kept, "v" to s.workshop.remMin), style = ui(12.5f, 400, G.ink2, 1.4f))
            GBtn(tr("bz.cutDone"), {
                if (!app.once()) return@GBtn
                val before = s.remnants
                s.setRemnantList(uz.metrx.app.furniture.cutDone(before, cost.layouts, s.mats, p.id, s.workshop.remMin, System.currentTimeMillis()) { uz.metrx.app.data.uid() })
                app.store.update(p.id) { it.copy(cutAt = System.currentTimeMillis()) }
                app.say("bz.cutSaved", "n" to kept, action = "common.undo") {
                    s.setRemnantList(before); app.store.update(p.id) { it.copy(cutAt = 0) }
                }
            }, Btn.SECONDARY, icon = "save", height = 46.dp, corner = 14.dp, fontSize = 14.5f, maxLines = 2)
        } else {
            Text(tr("bz.cutWas", "d" to time), style = ui(12.5f, 600, Color(0xFF15803D), 1.4f))
            GBtn(tr("bz.cutUndo"), {
                // an offcut of this order another order took was cut there: undoing would hand it out twice
                if (!uz.metrx.app.furniture.canUndoCut(s.remnants, p.id)) { app.say("bz.undoTaken", kind = uz.metrx.app.ui.components.ToastKind.ERROR); return@GBtn }
                s.setRemnantList(uz.metrx.app.furniture.cutUndone(s.remnants, p.id))
                app.store.update(p.id) { it.copy(cutAt = 0) }
            }, Btn.SECONDARY, icon = "undo", height = 44.dp, corner = 14.dp, fontSize = 14f)
        }
    }
}

/* ---------------- parts list → the part in 3D (Advanced) ---------------- */

/** The pieces and modules that have cut list line [r] ("pieceId|module" as Parts.kt names them), piece by piece. */
internal fun partHomes(fs: List<Furniture>, r: uz.metrx.app.furniture.CutRow, ws: uz.metrx.app.furniture.Workshop): Map<String, Set<String>> {
    val key = r.p.copy(mod = "", qty = 0)
    return fs.associate { f ->
        // a kitchen's end panels too (parts of no module)
        f.id to uz.metrx.app.furniture.partsWithMat(f, ws)
            .filter { (p, mat) -> p.copy(mod = "", qty = 0) == key && mat == r.mat }.map { (p, _) -> f.id + "|" + p.mod }.toSet()
    }.filterValues { it.isNotEmpty() }
}

/** A piece in 3D with part [r] lit up (inside parts with the doors hidden); [fid] the piece shown. */
@Composable
internal fun PartIn3D(p: Project, r: uz.metrx.app.furniture.CutRow, fid: String?, onPiece: (String) -> Unit, onClose: () -> Unit) {
    val app = LocalApp.current
    val s = app.settings
    val lang = LocalLang.current
    val homes = remember(p.furniture, r, s.workshop) { partHomes(p.furniture, r, s.workshop) }
    val f = p.furniture.firstOrNull { it.id == fid && it.id in homes } ?: p.furniture.firstOrNull { it.id in homes } ?: return
    // a piece in its room is shown on its own, taken out of the room
    val shown = remember(f) { if (f.roomId == null) f else uz.metrx.app.furniture.takenOut(f, { null }, null) }
    val bare = r.p.role != "front"
    val hi = uz.metrx.app.geo.PartHi(r.p.key, r.p.role, homes.getValue(f.id))
    val scene = remember(shown, hi.key, hi.mods, bare, s.mats) { pieceScene(shown, s.workshop, s.mats, bare, hi) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.7f)).padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(12.dp).clip(CircleShape).background(Color(0xFFF59E0B)))
            Text(tr(r.p.key) + " · ${r.p.L} × ${r.p.W} × ${r.p.qty}", style = ui(14f, 700), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Box(Modifier.size(40.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClose).semantics { contentDescription = app.t("common.close") }, contentAlignment = Alignment.Center) {
                MIcon("x", G.ink2, 18.dp, 2f)
            }
        }
        Box(Modifier.fillMaxWidth().aspectRatio(1f / .75f).clip(RoundedCornerShape(16.dp)).border(1.dp, G.rim, RoundedCornerShape(16.dp))) {
            PieceView(scene, null, null, Modifier.fillMaxSize())
            Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp))
        }
        if (homes.size > 1) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            homes.keys.forEach { id -> p.furniture.firstOrNull { it.id == id }?.let { g -> Chip(dn(g.name, lang), g.id == f.id) { onPiece(g.id) } } }
        }
        if (bare) Text(tr("bz.hiInside"), style = ui(12f, 400, G.ink2, 1.35f))
    }
}

/** The Rooms tab's "Change for all" button: the fronts and the handles of every piece. */
@Composable
internal fun SwapButton(p: Project) {
    val app = LocalApp.current
    if (p.furniture.count { it.modules.isNotEmpty() } < 1) return
    GBtn(tr("bz.swap"), { app.sheet = Sheet.FSwap(p.id) }, Btn.SECONDARY, icon = "layers", height = 48.dp, fontSize = 15f)
}
