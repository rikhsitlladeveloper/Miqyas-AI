package uz.metrx.app.ui.win

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import uz.metrx.app.core.Lang
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.elec.Ask
import uz.metrx.app.ui.elec.Option
import uz.metrx.app.ui.elec.Stepper
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.win.WKind
import uz.metrx.app.win.W_GROUPS
import uz.metrx.app.win.W_KINDS
import uz.metrx.app.win.ctxOf
import uz.metrx.app.win.fillOpening
import uz.metrx.app.win.newItem
import uz.metrx.app.win.openingsFor
import uz.metrx.app.win.wkind

/*
 * Choosing a product (22 Oct 2026): the gallery of types grouped as windows, balcony and doors, each card drawn by the
 * app from the product's own boxes in a piece of wall; then where it goes: the openings of the measured rooms it fits
 * (several at once), or without a room at a typed size.
 */

@Composable
fun WGalleryScreen(rt: Route.WGallery) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val op = rt.oid?.let { id -> room?.openings?.firstOrNull { it.id == id } }
    // an opening asked for: its groups first (a door opening: the doors)
    val groups = if (op?.type == "door") W_GROUPS.sortedBy { if (it == "door") 0 else if (it == "balc") 1 else 2 } else W_GROUPS
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val tops = remember { mutableStateMapOf<String, Int>() }
    val dens = LocalDensity.current.density
    LaunchedEffect(Unit) { WinPics.make((200 * dens).toInt(), (170 * dens).toInt(), dens) }
    val cur = if (scroll.maxValue > 0 && scroll.value >= scroll.maxValue - 4) groups.last()
        else groups.lastOrNull { (tops[it] ?: Int.MAX_VALUE) <= scroll.value + 60 } ?: groups.first()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        PageBar(frosted = true) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
            Spacer(Modifier.width(6.dp))
            BarTitle(tr("dw.galT"), eyebrow = dn(p.name, lang))
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            groups.forEach { g ->
                val on = g == cur
                Text(tr("dw.grp.$g"), style = ui(14f, 700, if (on) G.solid else G.ink), maxLines = 1,
                    modifier = Modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (on) G.ink else G.glass(.55f)).semantics { selected = on }
                        .clickable(role = Role.Tab) { scope.launch { scroll.animateScrollTo(tops[g] ?: 0) } }.padding(horizontal = 16.dp, vertical = 10.dp))
            }
        }
        Column(Modifier.weight(1f).verticalScroll(scroll).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (room != null) {
                val f = { mm: Int? -> fmtLen(mm, LenUnit.M, en) }
                Text(tr("tl.forRoom", "r" to roomName(p, room.id), "a" to f(room.dim("A").v), "b" to f(room.dim("B").v), "h" to f(room.dim("H").v)) +
                    (op?.let { " · " + openingName(room, it) + " " + sizeText(it.w, it.h) } ?: ""), style = ui(13.5f, 400, G.ink2, 1.4f))
            } else Text(tr("dw.galB"), style = ui(13.5f, 400, G.ink2, 1.4f))
            groups.forEach { g ->
                val ks = W_KINDS.filter { it.group == g }
                Row(Modifier.padding(top = 8.dp, start = 2.dp).onGloballyPositioned { tops[g] = it.positionInParent().y.toInt() }, verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("dw.grp.$g"), style = ui(17f, 800))
                    Text("${ks.size}", style = ui(12.5f, 500, G.ink3))
                }
                ks.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { k -> KindCard(k, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { app.push(Route.WPlace(p.id, k.id, rt.rid, rt.oid)) } }
                    }
                }
            }
            if (rt.fromNew) Text(tr("fz.needL"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp)
                .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.pop() }.padding(horizontal = 16.dp, vertical = 12.dp))
        }
    }
}

@Composable
private fun KindCard(k: WKind, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = tr("dw.k.${k.id}")
    val sub = tr("dw.kS.${k.id}")
    val pic: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.aspectRatio(200f / 170f).clip(RoundedCornerShape(14.dp)).background(Color(0xFFF6F8FC)), contentAlignment = Alignment.Center) {
            val img = WinPics.pics[k.id]
            if (img != null) Image(img, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) else Text("3D…", style = ui(11f, 600, G.ink3))
        }
    }
    val words: @Composable () -> Unit = {
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(name, style = ui(14.5f, 800, G.ink), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(sub, style = ui(12f, 500, G.ink2, 1.3f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
    val mod = modifier.clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = name }.padding(8.dp)
    if (wide) Row(mod, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        pic(Modifier.weight(1f)); Box(Modifier.weight(1f)) { words() }
    } else Column(mod, verticalArrangement = Arrangement.spacedBy(6.dp)) { pic(Modifier.fillMaxWidth()); words() }
}

/* ---------------- where it goes ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun WPlaceScreen(rt: Route.WPlace) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val k = wkind(rt.kind)
    val snap = app.settings.angleSnap
    val uw = tr("dw.mm")
    // the chosen openings ("room|opening"), or "free" for a typed size
    // the opening it came from, when this type fills it (no window in a door's opening, no door in a window's)
    var picks by rememberSaveable(rt) { mutableStateOf(listOfNotNull(if (rt.rid != null && rt.oid != null &&
        p.rooms.firstOrNull { it.id == rt.rid }?.openings?.firstOrNull { it.id == rt.oid }?.let { uz.metrx.app.win.fillsType(k.id, it.type) } == true) rt.rid + "|" + rt.oid else null)) }
    var free by rememberSaveable(rt) { mutableStateOf(p.rooms.isEmpty()) }
    var tw by rememberSaveable(rt) { mutableStateOf("${k.w}") }
    var th by rememberSaveable(rt) { mutableStateOf("${k.h}") }
    var qty by rememberSaveable(rt) { mutableStateOf(1) }
    val W = tw.toIntOrNull(); val H = th.toIntOrNull()
    val freeOk = W != null && H != null && W in 300..8000 && H in 300..4000
    val ok = if (free) freeOk else picks.isNotEmpty()
    var az by remember { mutableFloatStateOf(0f) }
    BackHandler { app.pop() }
    fun save() {
        if (!ok || !app.once()) return
        if (free) {
            val it0 = newItem(uid(), k, W!!, H!!, p.win.gap).copy(qty = qty)
            app.updateWin(p.id) { it.copy(items = it.items + it0) }
            app.popTo { it is Route.Project && it.id == p.id }
            app.push(Route.WDesign(p.id, it0.id)); app.say("dw.added", "n" to app.t("dw.k.${k.id}"))
            return
        }
        val made = picks.mapNotNull { pk ->
            val (rid, oid) = pk.split('|').let { it[0] to it[1] }
            val c = ctxOf(p, rid, snap) ?: return@mapNotNull null
            val o = c.opening(oid)?.takeIf { uz.metrx.app.win.fillsType(k.id, it.type) } ?: return@mapNotNull null
            fillOpening(uid(), k, c, o, p.win.gap)
        }
        if (made.isEmpty()) return
        // a product put in an opening takes the place of the one there
        app.updateWin(p.id) { e -> e.copy(items = e.items.filter { old -> made.none { it.roomId == old.roomId && it.opening == old.opening } } + made) }
        app.popTo { it is Route.Project && it.id == p.id }
        if (made.size == 1) app.push(Route.WDesign(p.id, made[0].id)) else app.push(Route.WView(p.id, made[0].roomId!!))
        app.say("dw.placed", "n" to made.size)
    }
    // with the keyboard up the footer goes under the fields (not over them), so the one typed in stays in sight
    val imeOn = androidx.compose.foundation.layout.WindowInsets.isImeVisible
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("dw.k.${k.id}"), eyebrow = tr("dw.whereE"))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (imeOn) 16.dp else 168.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val spec = remember(k.id) { samplePic(k.id) }
                Box(Modifier.fillMaxWidth().aspectRatio(1.5f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    Canvas(Modifier.fillMaxSize().pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az - dx / 400f).coerceIn(-.9f, .5f) } }) { drawProductPic(spec, az) }
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                Text(tr("dw.kS.${k.id}"), style = ui(13f, 500, G.ink2, 1.35f))
                Ask(tr("dw.whereT"), tr(if (k.isDoor) "dw.whereD" else "dw.whereW")) {
                    val rooms = p.rooms.sortedBy { if (it.id == rt.rid) 0 else 1 }
                    rooms.forEach { r ->
                        val c = ctxOf(p, r.id, snap)
                        Text(roomName(p, r.id), style = ui(15f, 800), modifier = Modifier.padding(top = 6.dp))
                        if (c == null) {
                            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.6f)).clickable { app.openRoom(p.id, r.id) }.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                MIcon("ruler", G.amberInk, 18.dp, 2f); Text(tr("dw.measureFirst"), style = ui(13.5f, 600, G.amberInk), modifier = Modifier.weight(1f))
                            }
                            return@forEach
                        }
                        val ops = openingsFor(c, k.id)
                        if (ops.isEmpty()) Text(tr(if (r.openings.isEmpty()) "dw.noOps" else "dw.noFit"), style = ui(13f, 400, G.ink2, 1.35f))
                        ops.forEach { o ->
                            val key = r.id + "|" + o.id
                            val on = key in picks
                            val now = p.win.items.firstOrNull { it.roomId == r.id && it.opening == o.id }
                            Check(openingName(r, o) + " · " + tr("tl.wallN", "w" to o.wall) + " · " + sizeText(o.w, o.h),
                                if (now != null) tr("dw.replaces", "n" to app.t("dw.k.${now.kind}")) else tr("dw.emptyOp"), on) {
                                free = false; picks = if (on) picks - key else picks + key
                            }
                        }
                    }
                    Option(tr("dw.freeOpt"), tr("dw.freeOptS"), free) { free = !free; if (free) picks = emptyList() }
                    if (free) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { c -> c.isDigit() }.take(4) }, "1300", number = true, labelRight = uw, modifier = Modifier.weight(1f))
                            GField(tr("tl.pbH"), th, { v -> th = v.filter { c -> c.isDigit() }.take(4) }, "1400", number = true, labelRight = uw, modifier = Modifier.weight(1f))
                        }
                        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(tr("dw.qty"), style = ui(15f, 600), modifier = Modifier.weight(1f))
                            Stepper(qty) { v -> qty = v.coerceIn(1, 99) }
                        }
                        if (!freeOk) Text(tr("dw.freeErr"), style = ui(13f, 500, G.err))
                    }
                }
            }
            if (imeOn) FloatingFooter(Modifier) {
            GBtn(if (free) tr("dw.putFree") else tr("dw.putN", "n" to picks.size), ::save, enabled = ok)
            }
        }
        if (!imeOn) FloatingFooter(Modifier.align(Alignment.BottomCenter)) {
            GBtn(if (free) tr("dw.putFree") else tr("dw.putN", "n" to picks.size), ::save, enabled = ok)
        }
    }
}

@Composable
internal fun Check(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape).semantics { selected = on }
        .clickable(role = Role.Checkbox, onClick = onClick).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(22.dp).clip(RoundedCornerShape(6.dp)).background(if (on) G.cobalt else Color.Transparent).border(2.dp, if (on) G.cobalt else G.ink3, RoundedCornerShape(6.dp)),
            contentAlignment = Alignment.Center) { if (on) MIcon("check", Color.White, 14.dp, 2.6f) }
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 700, if (on) G.cobalt2 else G.ink))
            Text(sub, style = ui(12.5f, 400, G.ink2, 1.35f))
        }
    }
}
