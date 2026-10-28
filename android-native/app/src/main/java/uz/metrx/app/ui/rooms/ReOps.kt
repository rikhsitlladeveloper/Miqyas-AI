package uz.metrx.app.ui.rooms

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Opening
import uz.metrx.app.data.SitePoint
import uz.metrx.app.geo.distsOf
import uz.metrx.app.geo.kindGroups
import uz.metrx.app.geo.styleId
import uz.metrx.app.ui.App
import uz.metrx.app.ui.furniture.Bubble
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UxBar
import uz.metrx.app.ui.ux.UxTop
import kotlin.math.roundToInt

/*
 * The room flow's openings step, redesigned (room editor v2, 27.10 (2)): the plan takes the whole height with a compact
 * A · B · C · D wall-chip row and the icon slider under it (the electrician sees the electric group first). An icon is
 * dragged onto a wall (the nearest one glows green, with a live preview), or tapped and then a wall or a chip, or a wall
 * is selected and then an icon tapped. Each drop opens the style window. A hand loops over the plan until the first
 * item is placed ("?" plays it again; with reduced motion a still arrow). A selected item gets a floating card over
 * the slider (no list panel); "N ta belgi" opens the list as a sheet.
 */

/** The phone asks for less motion (animations off): the coach is a still arrow. */
@Composable
fun reducedMotion(): Boolean {
    val ctx = LocalContext.current
    return remember { runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }.getOrDefault(false) }
}

/* ---------------- the icon slider ---------------- */

/**
 * The icons by group (separators between): a tap arms the icon (or puts it on the selected wall), a drag up carries it
 * onto the plan. [only] a single group (the editor's Nuqta tool).
 */
@Composable
fun IconRow(s: ReSession, geo: ReGeo, only: List<String>? = null, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val groups = if (only != null) listOf(only) else kindGroups(s.trade)
    Row(modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically) {
        groups.forEachIndexed { gi, g ->
            if (gi > 0) Box(Modifier.width(1.dp).height(44.dp).background(G.ink.copy(alpha = .1f)))
            g.forEach { k -> IconTile(s, geo, k, app) }
        }
    }
}

@Composable
private fun IconTile(s: ReSession, geo: ReGeo, k: String, app: App) {
    var root by remember { mutableStateOf(Offset.Zero) }
    val on = s.arm == k
    val shape = RoundedCornerShape(16.dp)
    Column(Modifier.width(74.dp).heightIn(min = 66.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .12f) else chipBg)
        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape)
        .onGloballyPositioned { root = it.positionInRoot() }
        .semantics { contentDescription = app.kindName(k) }
        .pointerInput(k) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                var drag = false; var moved = false
                while (true) {
                    val ev = awaitPointerEvent()
                    val c = ev.changes.firstOrNull { it.id == down.id } ?: break
                    if (!c.pressed) break
                    val dx = c.position.x - down.position.x; val dy = c.position.y - down.position.y
                    if (!drag) {
                        if (-dy > 8 * density && kotlin.math.abs(dy) > kotlin.math.abs(dx)) {
                            if (!s.inFlow && s.view == "3d") { app.say("re.no3dDrag", kind = uz.metrx.app.ui.components.ToastKind.INFO); moved = true; break }
                            drag = true; s.arm = null; app.haptic(Hap.TICK)
                        } else if (kotlin.math.abs(dx) > 10 * density) { moved = true; break }
                        else continue
                    }
                    c.consume()
                    val p = Offset(root.x + c.position.x, root.y + c.position.y)
                    val hit = app.dropTarget(s, geo, k, p)
                    s.ghost = Ghost(k, p.x, p.y, hit?.first, hit?.second)
                    s.mag = hit?.second?.let { m -> ((hit.first as? Opening)?.id ?: (hit.first as? SitePoint)?.id ?: "") to m }
                }
                if (drag) {
                    val g = s.ghost; s.ghost = null; s.mag = null
                    if (g?.it != null) app.beginPlace(s, g.it, "drag", fromFront = geo.view == "front")
                    else { app.haptic(Hap.WARN); app.say("re.nearer", kind = uz.metrx.app.ui.components.ToastKind.ERROR) }
                } else if (!moved) tileTap(app, s, k)
            }
        }.padding(vertical = 6.dp, horizontal = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)) {
        KindIcon(k, 24.dp)
        Text(app.kindName(k), style = ui(10.5f, 700, G.ink, 1.1f), textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

/** A tap on an icon: onto the selected wall's middle, else armed (tap a wall or a chip next). */
fun tileTap(app: App, s: ReSession, k: String) {
    val r = s.room ?: return
    val w = s.selWall
    if (w != null) { app.placeAt(s, k, w, app.wallL(r, w) / 2.0, "chip"); return }
    s.arm = if (s.arm == k) null else k
    s.sel = null
    app.haptic(Hap.TICK)
}

/** The label that follows the finger while an icon is carried. */
@Composable
fun BoxScope.GhostTag(s: ReSession, rootOrigin: Offset) {
    val app = LocalApp.current
    val g = s.ghost ?: return
    val r = s.room ?: return
    val ok = g.it != null
    val sub = when (val it = g.it) {
        is Opening -> { val d = distsOf(it, app.wallL(r, it.wall)); app.t("re.toWall", "w" to it.wall) to (mm(d.left) + " | " + mm(d.right) + " mm") }
        is SitePoint -> { val d = distsOf(it, app.wallL(r, it.wall)); app.t("re.toWall", "w" to it.wall) to (mm(d.left) + " | " + mm(d.right) + " mm") }
        else -> null to app.t("re.bringWall")
    }
    val d = LocalDensity.current
    Row(Modifier.offset { IntOffset((g.x - rootOrigin.x - 90 * d.density).roundToInt(), (g.y - rootOrigin.y - 86 * d.density).roundToInt()) }
        .widthIn(max = 260.dp).shadow(12.dp, RoundedCornerShape(14.dp)).clip(RoundedCornerShape(14.dp)).background(G.solid)
        .border(if (ok) 2.5.dp else 2.dp, if (ok) G.green else G.cobalt, RoundedCornerShape(14.dp)).padding(horizontal = 10.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        KindIcon(g.kind, 22.dp)
        Column {
            Text(app.kindName(g.kind) + (sub.first?.let { " → $it" } ?: ""), style = ui(12f, 800, G.ink), maxLines = 1)
            Text(sub.second + (g.mag?.let { " · " + app.t(if (it == "mid") "re.magMid" else "re.magCorner") } ?: ""), style = ui(10.5f, 700, G.ink2), maxLines = 1)
        }
    }
}

/* ---------------- the floating card ---------------- */

@Composable
private fun FcBtn(label: String, icon: String, red: Boolean = false, modifier: Modifier, onClick: () -> Unit) {
    Row(modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(if (red) G.err.copy(alpha = .1f) else G.cobalt.copy(alpha = .11f))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally)) {
        ReIcon(icon, if (red) G.err else G.cobalt2, 16.dp)
        Text(label, style = ui(13f, 800, if (red) G.err else G.cobalt2), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun RoundX(icon: String, label: String, onClick: () -> Unit) {
    Box(Modifier.size(38.dp).clip(CircleShape).background(chipBg).border(1.dp, G.rim, CircleShape).semantics { contentDescription = label }
        .clickable(role = Role.Button, onClick = onClick), contentAlignment = Alignment.Center) { ReIcon(icon, G.ink2, 17.dp) }
}

@Composable
private fun DistChip(v: Int, onClick: () -> Unit) {
    Text(mm(v), style = num(13f, 800, G.ink), modifier = Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(12.dp)).background(chipBg).border(1.dp, G.rim, RoundedCornerShape(12.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 10.dp, vertical = 8.dp))
}

/** The card over the icon row: the selected item (full or one line), the armed icon, or the selected wall. */
@Composable
fun FloatCard(s: ReSession, modifier: Modifier) {
    val app = LocalApp.current
    val r = s.room ?: return
    val o = s.selOp; val p = s.selPt
    val shape = RoundedCornerShape(22.dp)
    val base = modifier.fillMaxWidth().shadow(18.dp, shape).clip(shape).background(G.solid).border(1.dp, G.rim, shape)
    if (o != null || p != null) {
        val kind = o?.type ?: p!!.t; val wall = o?.wall ?: p!!.wall
        val L = app.wallL(r, wall)
        val d = if (o != null) distsOf(o, L) else distsOf(p!!, L)
        val nm = app.kindName(kind) + " · " + app.styleName(kind, if (o != null) styleId(o) else styleId(p!!))
        val size = if (o != null) app.sizeLine(o) else app.sizeLine(p!!)
        val issue = app.issuesOf(r).firstOrNull { it.id == (o?.id ?: p!!.id) }
        if (s.cardMin) {
            Row(base.padding(start = 8.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                KindBadge(kind, 32.dp)
                Column(Modifier.weight(1f)) {
                    Text(nm, style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(size + " · " + mm(d.left) + " | " + mm(d.right), style = num(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                RoundX("up", tr("re.cardOpen")) { s.cardMin = false; app.haptic(Hap.TICK) }
                RoundX("close", tr("re.desel")) { deselect(s) }
            }
            return
        }
        Column(base.padding(start = 12.dp, end = 10.dp, top = 10.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                KindBadge(kind, 36.dp)
                Column(Modifier.weight(1f)) {
                    Text(nm, style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("$size mm", style = num(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                RoundX("down", tr("re.cardMin")) { s.cardMin = true; app.haptic(Hap.TICK) }
                RoundX("close", tr("re.desel")) { deselect(s) }
            }
            val (ln, rn) = app.neighbours(r, wall)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("$ln ←", style = ui(12f, 700, G.ink2))
                DistChip(d.left) { app.openKp(s, "dl") }
                Text(tr("re.wallLen", "w" to wall, "v" to mm(L)), style = ui(11.5f, 700, G.ink3), textAlign = TextAlign.Center, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                DistChip(d.right) { app.openKp(s, "dr") }
                Text("→ $rn", style = ui(12f, 700, G.ink2))
            }
            if (issue != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReIcon("warn", G.amberInk, 18.dp); Text(app.issueText(issue), style = ui(12.5f, 600, G.ink, 1.3f), modifier = Modifier.weight(1f))
            }
            MiniFront(s, Modifier.fillMaxWidth().height(104.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                FcBtn(tr("re.t.type"), "grid", modifier = Modifier.weight(1f)) { app.pkOpenFor(s, "retype") }
                FcBtn(tr("re.t.size"), "ruler", modifier = Modifier.weight(1f)) { app.pkOpenFor(s, "resize") }
                FcBtn(tr("re.t.del"), "trash", red = true, modifier = Modifier.weight(1f)) { app.delSel(s) }
            }
        }
        return
    }
    val arm = s.arm
    if (arm != null) {
        Row(base.padding(start = 8.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            KindBadge(arm, 32.dp)
            Column(Modifier.weight(1f)) {
                Text(tr("re.armed", "n" to app.kindName(arm)), style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(tr("re.armedSub"), style = ui(12f, 500, G.ink2, 1.3f))
            }
            RoundX("close", tr("common.cancel")) { s.arm = null; app.haptic(Hap.TICK) }
        }
        return
    }
    val w = s.selWall ?: return
    val cnt = r.openings.count { it.wall == w } + r.points.count { it.wall == w }
    Row(base.padding(start = 8.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(32.dp).clip(RoundedCornerShape(10.dp)).background(G.cobalt), contentAlignment = Alignment.Center) { ReIcon("room", Color.White, 18.dp) }
        Column(Modifier.weight(1f)) {
            Text(tr("re.wallCard", "w" to w, "v" to mm(app.wallL(r, w)), "n" to cnt), style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(tr("re.wallCardSub"), style = ui(12f, 500, G.ink2, 1.3f))
        }
        RoundX("close", tr("re.desel")) { deselect(s) }
    }
}

/** The floating card's small front view of the selected item's wall: drag its edges, slide it, tap its sizes. */
@Composable
fun MiniFront(s: ReSession, modifier: Modifier) {
    val r = s.room ?: return
    val app = LocalApp.current
    val geo = remember { ReGeo() }
    val wall = s.selOp?.wall ?: s.selPt?.wall ?: return
    Box(modifier.clip(RoundedCornerShape(14.dp)).background(RP.paper)) {
        MiniFrontCanvas(s, geo, r, wall)
    }
}

@Composable
private fun MiniFrontCanvas(s: ReSession, geo: ReGeo, r: uz.metrx.app.data.Room, wall: String) {
    val app = LocalApp.current
    val u = LocalDensity.current.density
    val tm = rememberTextMeasurer()
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxSize().onGloballyPositioned { geo.bounds = it.boundsInRoot() }) {
        val W = constraints.maxWidth.toFloat(); val H = constraints.maxHeight.toFloat()
        val ff = frontFit(wall, app.wallL(r, wall), roomH(r), Rect(0f, 0f, W, H), true, u = u)
        geo.ff = ff; geo.frecs = frontRecs(r, ff, u); geo.view = "front"
        Box(Modifier.fillMaxSize().pointerInput(Unit) { miniGestures(app, s, geo) })
        val bad = app.issuesOf(r).map { it.id }.toSet()
        Canvas(Modifier.fillMaxSize()) { drawFront(r, ff, (s.sel as? ReSel.Item)?.id, false, null, bad, app.neighbours(r, wall), null, tm, u) }
        val o = s.selOp; val p = s.selPt
        if (o != null && o.wall == wall) {
            val xl = minOf(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble())); val xr = maxOf(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble()))
            val yt = ff.Z(opTop(o).toDouble()); val yb = ff.Z(uz.metrx.app.geo.z0Of(o).toDouble()); val yf = ff.Z(0.0)
            val off = 52 * u; var hx = xr + off; if (hx > W - 40 * u) hx = xl - off
            ReBubble(app.t("re.f.w").lowercase() + " " + mm(o.w), (xl + xr) / 2, yf + 12 * u, small = true, onClick = { app.openKp(s, "w") })
            ReBubble(app.t("re.f.h").lowercase() + " " + mm(o.h), hx, (yt + yb) / 2, small = true, onClick = { app.openKp(s, "h") })
            if (o.type == "window" && styleId(o) != "pano" && styleId(o) != "balcony")
                ReBubble(app.t("re.f.sill").lowercase() + " " + mm(o.sill), if (hx > xr) xl - off else xr + off, (yb + yf) / 2, small = true, onClick = { app.openKp(s, "sill") })
        } else if (p != null && p.wall == wall) {
            val x = ff.X(p.off.toDouble()); val y = ff.Z(p.h.toDouble())
            ReBubble("h " + mm(p.h), if (x + 50 * u > W - 30 * u) x - 50 * u else x + 50 * u, y, small = true, onClick = { app.openKp(s, "ph") })
        }
    }
}

/** The small front view's fingers: an edge handle changes the size, the item slides along (and a point up and down). */
private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.miniGestures(app: App, s: ReSession, geo: ReGeo) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val u = density
        val ff = geo.ff ?: return@awaitEachGesture
        val snap = s.room ?: return@awaitEachGesture
        val o = s.selOp; val pt = s.selPt
        val edge = o?.let { frontHandles(it, ff).minByOrNull { h -> kotlin.math.hypot(h.c.x - down.position.x, h.c.y - down.position.y) }?.takeIf { h -> kotlin.math.hypot(h.c.x - down.position.x, h.c.y - down.position.y) < 15 * u }?.e }
        val onItem = hitFront(geo.frecs, down.position, u) == (o?.id ?: pt?.id)
        if (edge == null && !onItem) return@awaitEachGesture
        val grab = ff.T(down.position.x) - (o?.off ?: pt!!.off)
        val hgrab = if (pt != null) ff.Hh(down.position.y) - pt.h else 0.0
        var changed = false
        while (true) {
            val ev = awaitPointerEvent()
            val c = ev.changes.firstOrNull { it.id == down.id } ?: break
            if (!c.pressed) break
            if (!changed && kotlin.math.hypot(c.position.x - down.position.x, c.position.y - down.position.y) < 4 * u) continue
            c.consume(); changed = true
            val p = c.position
            if (edge != null && o != null) {
                val L = ff.L; val t = ff.T(p.x); val hz = ff.Hh(p.y)
                var n = o
                when (edge) {
                    "l" -> { val t1 = o.off + o.w; val w = (Math.round((t1 - t) / 10) * 10).toInt().coerceIn(300, t1); n = o.copy(w = w, off = t1 - w) }
                    "r" -> { val w = (Math.round((t - o.off) / 10) * 10).toInt().coerceIn(300, maxOf(300, L - o.off)); n = o.copy(w = w) }
                    "t" -> { val z0 = uz.metrx.app.geo.z0Of(o); n = o.copy(h = (Math.round((hz - z0) / 10) * 10).toInt().coerceIn(300, maxOf(300, ff.rh - z0))) }
                    "b" -> { val top = o.sill + o.h; val ns = (Math.round(hz / 10) * 10).toInt().coerceIn(0, maxOf(0, top - 300)); n = o.copy(sill = ns, h = top - ns) }
                }
                if (n.balcony && n.w < n.dw + 300) n = n.copy(w = n.dw + 300)
                s.live = snap.copy(openings = snap.openings.map { if (it.id == o.id) n else it })
            } else {
                val L = ff.L
                val m = uz.metrx.app.geo.magnet(o?.w ?: 0, L, ff.T(p.x) - grab, (12 * u / ff.k).toDouble())
                s.mag = m.at?.let { (o?.id ?: pt!!.id) to it }
                if (o != null) s.live = snap.copy(openings = snap.openings.map { if (it.id == o.id) it.copy(off = m.v) else it })
                else { val hz = ff.Hh(p.y) - hgrab; val nh = ptSnaps(pt!!.t).filter { kotlin.math.abs(hz - it) < 120 }.minByOrNull { kotlin.math.abs(hz - it) } ?: (Math.round(hz / 10) * 10).toInt().coerceIn(0, ff.rh)
                    s.live = snap.copy(points = snap.points.map { if (it.id == pt.id) it.copy(off = m.v, h = nh) else it }) }
            }
        }
        s.mag = null
        if (!changed) { s.live = null; return@awaitEachGesture }
        val r1 = s.live ?: return@awaitEachGesture
        val oo = r1.openings.firstOrNull { it.id == o?.id }; val pp = r1.points.firstOrNull { it.id == pt?.id }
        val msg = if (edge != null && oo != null) app.t("re.edgeCh", "n" to app.kindName(oo.type), "v" to app.sizeLine(oo))
            else { val L = ff.L; val d = if (oo != null) distsOf(oo, L) else distsOf(pp!!, L); app.t("re.moved", "n" to app.kindName(oo?.type ?: pp!!.t), "a" to mm(d.left), "b" to mm(d.right)) }
        s.endLive(app, snap, msg)
    }
}

/* ---------------- the list sheet ---------------- */

@Composable
fun BoxScope.ListSheet(s: ReSession) {
    val app = LocalApp.current
    val r = s.room ?: return
    if (!s.listOpen) return
    val iss = app.issuesOf(r).associateBy { it.id }
    Box(Modifier.fillMaxSize().background(Color(0x6B0F172A)).clickable(remember { MutableInteractionSource() }, null) { s.listOpen = false })
    Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().clip(RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)).background(G.solid)
        .clickable(remember { MutableInteractionSource() }, null) {}.navigationBarsPadding().padding(16.dp).heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.align(Alignment.CenterHorizontally).size(40.dp, 5.dp).clip(RoundedCornerShape(3.dp)).background(G.ink.copy(alpha = .12f)))
        Text(tr("re.listT", "n" to (r.openings.size + r.points.size)), style = ui(19f, 800), modifier = Modifier.padding(top = 8.dp))
        Text(tr("re.listSub"), style = ui(12.5f, 500, G.ink2))
        (r.openings + r.points).forEach { x ->
            val id = (x as? Opening)?.id ?: (x as SitePoint).id
            val kind = (x as? Opening)?.type ?: (x as SitePoint).t
            val wall = (x as? Opening)?.wall ?: (x as SitePoint).wall
            val L = app.wallL(r, wall)
            val d = if (x is Opening) distsOf(x, L) else distsOf(x as SitePoint, L)
            val st = if (x is Opening) styleId(x) else styleId(x as SitePoint)
            val on = (s.sel as? ReSel.Item)?.id == id
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else Color.Transparent)
                .clickable(role = Role.Button) { s.listOpen = false; selectItem(app, s, id) }.padding(horizontal = 6.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                KindBadge(kind, 30.dp)
                Column(Modifier.weight(1f)) {
                    Text(app.kindName(kind) + " · " + app.styleName(kind, st), style = ui(13.5f, 800))
                    Text(tr("re.wall", "w" to wall) + " · " + (if (x is Opening) app.sizeLine(x) else app.sizeLine(x as SitePoint)) + " · " + mm(d.left) + " | " + mm(d.right), style = num(12f, 500, G.ink2))
                    iss[id]?.let { Text(app.issueText(it), style = ui(12f, 700, RP.issue)) }
                }
            }
        }
        Text(tr("common.close"), style = ui(14.5f, 700, G.ink2), textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(min = 44.dp)
            .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { s.listOpen = false }.padding(horizontal = 16.dp, vertical = 12.dp))
    }
}

/* ---------------- the hand animation ---------------- */

/**
 * The coach over the plan: a ghost icon from the first tile up onto wall A, the wall glows, it drops in; 3.6 s, looped
 * until the first item is placed ([ReSession.coachPlay] plays it twice more). Reduced motion: a still dashed arrow.
 */
@Composable
fun BoxScope.Coach(s: ReSession, geo: ReGeo, tileRoot: Offset?, rootOrigin: Offset) {
    val r = s.room ?: return
    val on = s.pk == null && s.sel == null && s.arm == null && s.ghost == null && !s.listOpen && s.kp == null && (s.coachPlay > 0 || (r.openings.isEmpty() && r.points.isEmpty() && !s.coachStop))
    val fit = geo.fit
    if (!on || fit == null || tileRoot == null) return
    val still = reducedMotion()
    val t = remember { Animatable(0f) }
    LaunchedEffect(s.coachPlay, still) {
        if (still) { if (s.coachPlay > 0) { kotlinx.coroutines.delay(4500); s.coachPlay = 0 }; return@LaunchedEffect }
        while (true) {
            t.snapTo(0f); t.animateTo(1f, tween(3600, easing = LinearEasing))
            if (s.coachPlay > 0) { s.coachPlay -= 1; if (s.coachPlay == 0 && (r.openings.isNotEmpty() || r.points.isNotEmpty() || s.coachStop)) break }
        }
    }
    val f = fit.frames.first()
    val ox = geo.bounds.left - rootOrigin.x; val oy = geo.bounds.top - rootOrigin.y
    val x0 = tileRoot.x - rootOrigin.x; val y0 = tileRoot.y - rootOrigin.y
    val m = Offset((f.a.x + f.b.x) / 2 + ox, (f.a.y + f.b.y) / 2 + oy)
    val a = Offset(f.a.x + ox, f.a.y + oy); val b = Offset(f.b.x + ox, f.b.y + oy)
    val green = RP.green; val cob = G.cobalt; val ink = G.ink; val sheet = G.solid
    val d = LocalDensity.current.density
    val v = t.value
    fun seg(a0: Float, a1: Float) = ((v - a0) / (a1 - a0)).coerceIn(0f, 1f)
    Canvas(Modifier.fillMaxSize()) {
        if (still) {
            drawLine(green.copy(alpha = .35f), a, b, 12 * d, StrokeCap.Round)
            val p0 = Offset(x0, y0 - 34 * d); val c = Offset((x0 + m.x) / 2 + 46 * d, (y0 + m.y) / 2); val p1 = Offset(m.x, m.y + 26 * d)
            drawPath(Path().apply { moveTo(p0.x, p0.y); quadraticTo(c.x, c.y, p1.x, p1.y) }, cob, style = Stroke(2.5f * d, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(7 * d, 6 * d))))
            val ux = p1.x - c.x; val uy = p1.y - c.y; val ul = kotlin.math.hypot(ux, uy).coerceAtLeast(1f); val nx = ux / ul; val ny = uy / ul
            drawPath(Path().apply { moveTo(p1.x, p1.y); lineTo(p1.x - nx * 11 * d - ny * 6 * d, p1.y - ny * 11 * d + nx * 6 * d); lineTo(p1.x - nx * 11 * d + ny * 6 * d, p1.y - ny * 11 * d - nx * 6 * d); close() }, cob)
            return@Canvas
        }
        // wall glow 42–76 %
        val ga = if (v < .42f) 0f else if (v < .5f) seg(.42f, .5f) * .6f else if (v < .63f) .6f else (1 - seg(.63f, .76f)) * .6f
        if (ga > 0) drawLine(green.copy(alpha = ga), a, b, 14 * d, StrokeCap.Round)
        // the ghost icon 14–74 %: from the tile to the wall
        val gt = seg(.2f, .56f)
        val gp = Offset(x0 + (m.x - x0) * gt, y0 + (m.y + 4 * d - y0) * gt)
        val ghA = if (v < .14f) 0f else if (v < .2f) seg(.14f, .2f) else if (v < .64f) 1f else (1 - seg(.64f, .74f))
        val sc = if (v < .2f) .8f + .2f * seg(.14f, .2f) else if (v < .56f) 1f else 1f - .6f * seg(.56f, .74f)
        if (ghA > 0) {
            val hs = 27 * d * sc
            drawRoundRect(sheet.copy(alpha = ghA), Offset(gp.x - hs, gp.y - hs), androidx.compose.ui.geometry.Size(2 * hs, 2 * hs), androidx.compose.ui.geometry.CornerRadius(16 * d * sc))
            drawRoundRect(cob.copy(alpha = ghA), Offset(gp.x - hs, gp.y - hs), androidx.compose.ui.geometry.Size(2 * hs, 2 * hs), androidx.compose.ui.geometry.CornerRadius(16 * d * sc), style = Stroke(2 * d))
            glyph("door", gp, 28 * d * sc, kindColor("door").copy(alpha = ghA), 2f)
        }
        // the hand follows, under the finger
        val hA = if (v < .08f) seg(0f, .08f) else if (v < .64f) 1f else (1 - seg(.64f, .76f))
        val hp = if (v < .2f) Offset(x0, y0 + 34 * d * (1 - seg(0f, .14f))) else if (v < .56f) gp else Offset(m.x, m.y + 14 * d + 20 * d * seg(.64f, .76f))
        if (hA > 0) {
            val k = 42 * d / 24f
            translate(hp.x - 12 * d, hp.y - 6 * d) {
                scale(k, k, Offset.Zero) {
                    val hand = androidx.compose.ui.graphics.vector.PathParser().parsePathString(RE_ICONS["hand"]!!).toPath()
                    drawPath(hand, sheet.copy(alpha = hA)); drawPath(hand, ink.copy(alpha = hA), style = Stroke(1.5f))
                }
            }
        }
    }
    Row(Modifier.align(Alignment.TopCenter).offset { IntOffset(0, (geo.bounds.bottom - rootOrigin.y - 52 * d).roundToInt()) }.clip(RoundedCornerShape(15.dp)).background(G.solid)
        .border(1.dp, G.rim, RoundedCornerShape(15.dp)).padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        ReIcon("hand", G.cobalt, 16.dp); Text(tr("re.coach"), style = ui(12f, 700, G.ink2))
    }
}

/* ---------------- the step ---------------- */

/** The room flow's openings step for draft [d], on its working room [RshDraft.tmp]. */
@Composable
fun ReOpsStep(d: RshDraft, onBack: () -> Unit, onDone: () -> Unit) {
    val app = LocalApp.current
    val key = "rsh:" + d.key
    val s = ReSessions.get(key) ?: ReSession(key, if (d.trade == "into" || d.trade == "build") "build" else d.trade, true, d.pid, null, { d.tmp }, { d.tmp = it }).also { ReSessions.put(it) }
    val r = s.room ?: return
    val geo = remember { ReGeo() }
    var rootOrigin by remember { mutableStateOf(Offset.Zero) }
    var firstTile by remember { mutableStateOf<Offset?>(null) }
    var cardH by remember { mutableFloatStateOf(0f) }
    var bottomH by remember { mutableFloatStateOf(0f) }
    var chipsH by remember { mutableFloatStateOf(0f) }
    val u = LocalDensity.current.density
    Box(Modifier.fillMaxSize().onGloballyPositioned { rootOrigin = it.positionInRoot() }) {
        Column(Modifier.fillMaxSize()) {
            UxTop(tr("re.opsT"), onBack, eyebrow = tr("re.opsSub", "n" to uz.metrx.app.data.dn(d.name, app.settings.lang)), right = {
                Box(Modifier.size(46.dp).clip(CircleShape).background(chipBg).border(1.dp, G.rim, CircleShape).semantics { contentDescription = app.t("re.coachAgain") }
                    .clickable(role = Role.Button) { s.coachPlay = 2; s.sel = null; s.arm = null; app.haptic(Hap.TICK) }, contentAlignment = Alignment.Center) {
                    Text("?", style = ui(20f, 800, G.cobalt))
                }
            })
            Column(Modifier.weight(1f).padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(RP.paper).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    ReCanvas(s, geo, Modifier.fillMaxSize(), avoid = if (s.selOp != null || s.selPt != null) cardH + 6 * u else 0f)
                    val n = r.openings.size + r.points.size
                    if (n > 0 && s.pk == null) Row(Modifier.align(Alignment.TopEnd).padding(10.dp).heightIn(min = 32.dp).clip(RoundedCornerShape(16.dp)).background(G.solid)
                        .border(1.dp, G.rim, RoundedCornerShape(16.dp)).clickable(role = Role.Button) { s.listOpen = true }.padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ReIcon("list", G.cobalt, 16.dp); Text(tr("re.nItems", "n" to n), style = ui(12.5f, 800))
                    }
                }
                Box(Modifier.onSizeChanged { chipsH = it.height.toFloat() }) { WallChips(s, r) }
            }
            Column(Modifier.fillMaxWidth().onSizeChanged { bottomH = it.height.toFloat() }) {
            Column(Modifier.fillMaxWidth().then(uz.metrx.app.ui.ux.barSpotModifier()).background(G.sheet(.97f))) {
                Row(Modifier.padding(start = 14.dp, end = 12.dp, top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("re.iconsT"), style = ui(12.5f, 800)); Text(tr("re.iconsSub"), style = ui(11.5f, 600, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Box(Modifier.onGloballyPositioned { c -> if (firstTile == null) { val p = c.positionInRoot(); firstTile = Offset(p.x + 8 * u + 37 * u, p.y + 4 * u + 33 * u) } }) { IconRow(s, geo) }
            }
            UxBar(tr(if (r.openings.isNotEmpty() || r.points.isNotEmpty()) "rsh.ready" else "rsh.skip"), null, { s.sel = null; onDone() }, { s.undo(app) }, s.canUndo, { s.redo(app) }, s.canRedo)
            }
        }
        // the floating card, just above the icon row
        if (s.pk == null && (s.sel != null || s.arm != null)) Box(Modifier.align(Alignment.BottomCenter).padding(start = 10.dp, end = 10.dp, bottom = with(LocalDensity.current) { (bottomH + chipsH).toDp() } + 14.dp).then(uz.metrx.app.ui.ux.barSpotModifier())
            .onSizeChanged { cardH = it.height.toFloat() }) {
            FloatCard(s, Modifier)
        }
        Coach(s, geo, firstTile, rootOrigin)
        GhostTag(s, rootOrigin)
        ListSheet(s)
        PickWindow(s)
        KeypadOverlay(s)
    }
}

/** "Devor  A 3 400 · B 2 600 …": tap one to select it (an armed icon goes onto it). */
@Composable
fun WallChips(s: ReSession, r: uz.metrx.app.data.Room) {
    val app = LocalApp.current
    val ws = reWalls(r, app.reSnap())
    val hl = (s.ghost?.it as? Opening)?.wall ?: (s.ghost?.it as? SitePoint)?.wall ?: s.pk?.takeIf { it.mode == "new" }?.wall
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(tr("re.wallW"), style = ui(11.5f, 700, G.ink2), modifier = Modifier.padding(horizontal = 2.dp))
        ws.forEach { w ->
            val on = s.selWall == w.id; val lit = hl == w.id; val pick = s.arm != null
            Column(Modifier.widthIn(min = 54.dp).heightIn(min = 38.dp).clip(RoundedCornerShape(11.dp)).background(if (lit) RP.green else if (on) G.cobalt else chipBg)
                .border(if (pick && !on && !lit) 2.dp else 1.dp, if (pick && !on && !lit) G.cobalt else G.rim, RoundedCornerShape(11.dp))
                .clickable(role = Role.Button) { val a = s.arm; if (a != null) app.placeAt(s, a, w.id, w.L / 2.0, "chip") else selectWall(app, s, w.id) }.padding(horizontal = 6.dp, vertical = 3.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Text(w.id, style = ui(13f, 800, if (on || lit) Color.White else if (pick) G.cobalt2 else G.ink))
                Text(mm(w.L), style = num(9.5f, 700, if (on || lit) Color.White.copy(alpha = .85f) else G.ink3))
            }
        }
    }
}
