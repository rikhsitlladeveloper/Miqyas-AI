package uz.metrx.app.ui.projects

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Phone
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.stats
import uz.metrx.app.data.wsCounts
import uz.metrx.app.data.wsIcon
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BackPill
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.main.NAV_SPACE
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.theme.num

private val TABS = listOf("rooms" to "pj.t.rooms", "estimate" to "pr.estimate", "quotes" to "pj.t.quotes", "info" to "pj.info")
/** A furniture order: its price tab instead of the estimate (furniture plan section 4). */
private val F_TABS = listOf("rooms" to "fo.rooms", "price" to "fo.price", "quotes" to "pj.t.quotes", "info" to "pj.info")
// the simple furniture app: the rooms with their furniture, and who it is for
private val F_TABS_SIMPLE = listOf("rooms" to "fo.rooms", "info" to "pj.info")

/** Project page: name, customer and stage, three numbers, four tabs (prototype project.js + glass stage 2). */
@Composable
fun ProjectScreen(r: Route.Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(r.id) ?: return
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        // the pill names the page underneath: the orders list on that tab, or Home or Profile when opened from there
        val under = app.tab.takeIf { app.stack.size >= 2 && app.stack[app.stack.size - 2] == uz.metrx.app.ui.Route.Root && it != uz.metrx.app.ui.main.Tab.PROJECTS }
        PageBar { BackPill(tr(under?.label ?: if (p.isFurniture) "fo.tab" else "tab.projects"), { app.pop() }) }
        val withTotal = r.tab == "estimate" && (p.estimate.materials.isNotEmpty() || p.estimate.labor.isNotEmpty())
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(bottom = if (withTotal) 0.dp else 24.dp + NAV_SPACE).let { if (withTotal) it else it.navigationBarsPadding() }) {
            // price and quotes are the advanced app's; a link to them opens the rooms
            val tab = if (p.isFurniture && !app.settings.advanced && (r.tab == "price" || r.tab == "quotes")) "rooms" else r.tab
            Header(p, tab, lang)
            // a furniture order: what to do now, with the one button that does it
            if (p.isFurniture) uz.metrx.app.ui.furniture.NextStep(p)
            when (tab) {
                "info" -> { if (p.isFurniture) uz.metrx.app.ui.furniture.FurnitureInfo(p); InfoTab(p, lang) }
                "price" -> uz.metrx.app.ui.furniture.FPriceTab(p)
                "quotes" -> QuotesTab(p, lang)
                "estimate" -> EstimateTab(p, lang)
                else -> if (r.view != "list" && p.rooms.isNotEmpty()) Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp)) {
                    ViewSeg(r.view) { app.setTop(r.copy(view = it)) }
                    if (r.view == "2d") Plans2D(p, lang) else Project3D(p, r, lang)
                } else if (p.isFurniture) uz.metrx.app.ui.furniture.FRoomsTab(p, lang, r) else WorkspacesTab(p, lang, r)
            }
        }
        // the total floats over the tab bar, the rows scroll above it (prototype .footer.gs-tot)
        if (withTotal) Column(Modifier.navigationBarsPadding().padding(bottom = NAV_SPACE - 12.dp)) { EstimateTotal(p, lang) }
    }
}

@Composable
private fun Header(p: Project, tab: String, lang: Lang) {
    val app = LocalApp.current
    val context = LocalContext.current
    val sub = (if (p.isFurniture) uz.metrx.app.ui.furniture.orderSub(p, lang, ", ") else listOf(dn(p.customer, lang), dn(p.address, lang)).filter { it.isNotBlank() }.joinToString(", ")).ifEmpty { "—" }
    val shape = RoundedCornerShape(30.dp)
    Column(
        Modifier.padding(start = 20.dp, end = 20.dp, top = 6.dp).fillMaxWidth()
            .dropShadow(shape, Shadow(36.dp, G.shade.copy(alpha = .14f), offset = DpOffset(0.dp, 16.dp)))
            .clip(shape).background(G.glass(.4f)).topHighlight().border(1.dp, G.rim, shape)
            .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 14.dp)
    ) {
        // a furniture order's other tabs: one line, so the tab's own content starts higher
        if (p.isFurniture && tab != "rooms") Row(Modifier.padding(start = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(dn(p.name, lang), style = ui(17f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            uz.metrx.app.ui.furniture.FStageChip(p.stage)
            RoundIc("more", tr("common.menu")) { app.sheet = Sheet.ProjectMenu(p.id) }
        } else Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // a furniture order's name is often long ("Kitchen and wardrobe — Akmal Yusupov"): a bit smaller, two lines
                Text(dn(p.name, lang), style = ui(if (p.isFurniture) 23f else 28f, 800, G.ink, 1.15f, -.02f), maxLines = if (p.isFurniture) 2 else Int.MAX_VALUE,
                    overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f).padding(top = 2.dp))
                if (p.isFurniture) uz.metrx.app.ui.furniture.CallButton(p)
                else if (p.phone.isNotEmpty()) RoundIc("phone", tr("pl.call")) { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:+998" + Phone.digits(p.phone)))) }
                if (p.location != null) RoundIc("pin", tr("loc.open")) { openMap(context, p) }
                RoundIc("more", tr("common.menu")) { app.sheet = Sheet.ProjectMenu(p.id) }
            }
            // the simple furniture app shows no stage: with no address either, the line goes
            if (!(p.isFurniture && sub == "—" && !app.settings.advanced)) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(if (p.isFurniture && sub == "—") "" else sub, style = ui(13.5f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                if (p.isFurniture) uz.metrx.app.ui.furniture.FStageChip(p.stage) else StageChip(p.stage)
            }
        }
        if (tab == "rooms") { if (p.isFurniture) uz.metrx.app.ui.furniture.FNums(p) else Nums(p) }
        Row(
            Modifier.padding(top = 12.dp).fillMaxWidth().height(44.dp).clip(RoundedCornerShape(22.dp)).background(G.ink.copy(alpha = .06f)).padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            (if (!p.isFurniture) TABS else if (app.settings.advanced) F_TABS else F_TABS_SIMPLE).forEach { (k, l) ->
                val on = tab == k
                val bubble = RoundedCornerShape(18.dp)
                Box(
                    Modifier.weight(1f).fillMaxHeight()
                        .let { if (on) it.dropShadow(bubble, Shadow(10.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 3.dp))) else it }
                        .clip(bubble).background(if (on) G.glass(.95f) else Color.Transparent)
                        .clickable(role = Role.Tab) { app.setProjectTab(k) }.padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        // the name shrinks so the quotes count always has room (it was cut off with a large system font)
                        androidx.compose.foundation.text.BasicText(tr(l), Modifier.weight(1f, fill = false), style = ui(12.5f, if (on) 700 else 600, if (on) G.ink else G.slate), maxLines = 1,
                            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 12.5.sp, stepSize = .5.sp))
                        if (k == "quotes" && p.quotes.isNotEmpty()) Text("${p.quotes.size}", style = ui(11f, 700, Color.White), maxLines = 1, softWrap = false,
                            modifier = Modifier.clip(CircleShape).background(G.cobalt).padding(horizontal = 6.dp, vertical = 1.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun RoundIc(icon: String, label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).dropShadow(CircleShape, Shadow(18.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, 6.dp)))
            .clip(CircleShape).background(G.glass(.45f)).topHighlight(1f, 1.dp).border(1.dp, G.rim, CircleShape)
            .pressable(onClick, .95f, label = label),
        contentAlignment = Alignment.Center
    ) { MIcon(icon, G.ink, 18.dp, 2f) }
}

/** The project stage as a coloured chip (prototype .pc-st). */
@Composable
fun StageChip(stage: String) {
    val (bg, fg) = when (stage) {
        "measure" -> G.amberWash to G.amberInk
        "done" -> Color(0x2416A34A) to (if (Theme.dark) G.green else Color(0xFF15803D))
        else -> G.cobalt.copy(alpha = .12f) to G.cobalt2
    }
    Text(tr("stage.$stage"), style = ui(12f, 600, fg), maxLines = 1, modifier = Modifier.clip(CircleShape).background(bg).padding(horizontal = 10.dp, vertical = 4.dp))
}

/** "Devor, sof · O‘lchangan · Smeta" — the three numbers a brickmason prices by. */
@Composable
private fun Nums(p: Project) {
    val st = stats(p, LocalApp.current.settings.angleSnap)
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).padding(start = 4.dp, end = 4.dp, top = 10.dp)) {
            NumCell(tr("pl.wall"), when { p.rooms.isEmpty() -> "—"; st.nets == 0 -> "?"; else -> uz.metrx.app.geo.fmtArea(st.net, uz.metrx.app.ui.theme.LocalLang.current == Lang.EN) + if (st.nets < p.rooms.size) " +?" else "" },
                Modifier.weight(1f), unit = if (st.nets > 0) tr("u.m2") else null)
            VLine()
            NumCell(tr("pl.meas"), if (st.need > 0) "${st.conf}/${st.need}" else "—", Modifier.weight(1f).padding(start = 12.dp))
            VLine()
            val (est, estUnit) = uz.metrx.app.core.shortMoney(p, uz.metrx.app.core.totals(p).g, uz.metrx.app.ui.theme.LocalLang.current == Lang.EN, tr("pl.mln"))
            NumCell(tr("pl.est"), est, Modifier.weight(1f).padding(start = 12.dp), unit = estUnit)
        }
    }
}

@Composable
private fun VLine() = Box(Modifier.width(1.dp).fillMaxHeight().padding(vertical = 2.dp).background(G.ink.copy(alpha = .08f)))

@Composable
private fun NumCell(label: String, value: String, modifier: Modifier, unit: String? = null) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, style = num(17f, 800), maxLines = 1)
            if (unit != null) Text(" $unit", style = ui(10.5f, 600, G.ink2), modifier = Modifier.padding(bottom = 2.dp))
        }
    }
}

/* ---------------- Workspaces tab ---------------- */

@Composable
private fun WorkspacesTab(p: Project, lang: Lang, route: Route.Project) {
    val app = LocalApp.current
    if (p.floors.isEmpty()) {
        Column(
            Modifier.padding(start = 16.dp, end = 16.dp, top = 14.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f))
                .padding(start = 20.dp, end = 20.dp, top = 26.dp, bottom = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            EmptyWorkspaces()
            Text(tr("ws.emptyT"), style = ui(19f, 700, G.ink, 1.4f), textAlign = TextAlign.Center)
            Text(tr("ws.emptyB"), style = ui(14.5f, 400, G.ink2, 1.4f), textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 6.dp))
            GBtn(tr("ws.create"), { app.sheet = Sheet.NewSpace(p.id) }, icon = "plus")
        }
        return
    }
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        p.floors.forEach { w ->
            Row(
                Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).pressable({ app.push(Route.Space(p.id, w.id)) })
                    .padding(start = 10.dp, end = 8.dp, top = 10.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                val r0 = p.rooms.firstOrNull { it.floorId == w.id }
                Box(Modifier.size(66.dp, 52.dp).clip(RoundedCornerShape(10.dp)).background(G.ink.copy(alpha = .06f)), contentAlignment = Alignment.Center) {
                    if (r0 != null) uz.metrx.app.editorThumb(r0, Modifier.fillMaxSize().padding(3.dp))
                    else MIcon(wsIcon(w.type), G.cobalt, 26.dp, 2f)
                }
                Column(Modifier.weight(1f)) {
                    Text(floorName(w, lang), style = ui(15.5f, 600), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(wsCounts(p, w, lang).ifEmpty { tr("ws.empty") }, style = ui(12.5f, 400, G.ink2, 1.3f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                val (net, nn) = uz.metrx.app.data.wsNet(p, w, app.settings.angleSnap)
                if (nn > 0) Column(horizontalAlignment = Alignment.End) {
                    Text(uz.metrx.app.geo.fmtArea(net, lang == Lang.EN) + " " + tr("u.m2"), style = num(14.5f, 700))
                    Text(tr("pj.wsNet"), style = ui(11.5f, 400, G.ink2))
                }
                MIcon("chev", G.ink3, 18.dp, 2f)
            }
        }
        if (p.rooms.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", modifier = Modifier.weight(1f), height = 48.dp, fontSize = 15f)
            GBtn(tr("pj.v3d"), { app.setTop(route.copy(view = "3d")) }, Btn.SECONDARY, icon = "cube", modifier = Modifier.weight(1f), height = 48.dp, fontSize = 15f)
        }
        Row(
            Modifier.fillMaxWidth().height(64.dp).dashedGlass(24.dp).pressable({ app.sheet = Sheet.NewSpace(p.id) }, .98f),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
        ) {
            MIcon("plus", G.cobalt2, 22.dp, 2.2f)
            Text(tr("gl.addWs"), style = ui(16f, 700, G.cobalt2))
        }
    }
}

/** The two-sheet drawing of the empty Workspaces tab (prototype .ws-empty svg, 120 × 84). */
@Composable
private fun EmptyWorkspaces() {
    Canvas(Modifier.size(120.dp, 84.dp)) {
        val k = size.width / 120f
        scale(k, k, pivot = Offset.Zero) {
            drawRoundRect(if (Theme.dark) G.blueWash else Color(0xFFEAF0FE), Offset(8f, 10f), Size(64f, 48f), CornerRadius(6f))
            drawRoundRect(Color(0xFF1C4BD1), Offset(8f, 10f), Size(64f, 48f), CornerRadius(6f), style = Stroke(2f))
            drawRoundRect(G.solid, Offset(48f, 26f), Size(64f, 48f), CornerRadius(6f))
            drawRoundRect(G.ink, Offset(48f, 26f), Size(64f, 48f), CornerRadius(6f), style = Stroke(2f))
            drawLine(Color(0xFF5F6B82), Offset(60f, 44f), Offset(100f, 44f), 2f, StrokeCap.Round)
            drawLine(Color(0xFF5F6B82), Offset(60f, 54f), Offset(86f, 54f), 2f, StrokeCap.Round)
            drawCircle(Color(0xFF1C4BD1), 13f, Offset(98f, 68f))
            drawLine(Color.White, Offset(98f, 62f), Offset(98f, 74f), 2.4f, StrokeCap.Round)
            drawLine(Color.White, Offset(92f, 68f), Offset(104f, 68f), 2.4f, StrokeCap.Round)
        }
    }
}

/* ---------------- Details tab ---------------- */

@Composable
private fun InfoTab(p: Project, lang: Lang) {
    val app = LocalApp.current
    val context = LocalContext.current
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        val shape = RoundedCornerShape(22.dp)
        Column(Modifier.fillMaxWidth().glassCard(shape, fill = G.glass(.55f)).padding(horizontal = 12.dp)) {
            Kv(tr("pr.customer"), dn(p.customer, lang).ifEmpty { "—" })
            Hairline()
            Kv(tr("pr.phone"), if (p.phone.isNotEmpty()) Phone.format(p.phone) else tr("pj.noPhone")) {
                if (p.phone.isNotEmpty()) GBtn(tr("pl.call"), { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:+998" + Phone.digits(p.phone)))) },
                    Btn.SECONDARY, icon = "phone", height = 40.dp, corner = 14.dp, fontSize = 14f, fill = false)
            }
            Hairline()
            Kv(tr("pr.address"), dn(p.address, lang).ifEmpty { "—" })
            Hairline()
            Kv(tr("pr.location"), p.location?.let { "%.5f, %.5f".format(java.util.Locale.ROOT, it.lat, it.lng) } ?: tr("loc.none")) {
                if (p.location != null) GBtn(tr("loc.open"), { openMap(context, p) }, Btn.SECONDARY, icon = "pin", height = 40.dp, corner = 14.dp, fontSize = 14f, fill = false)
            }
            // the simple furniture app has no prices, so no currency either
            if (!p.isFurniture || app.settings.advanced) { Hairline(); Kv(tr("np.currency"), p.currency) }
            Hairline()
            Kv(tr("rpt.lang"), Lang.of(p.reportLang).longName)
        }
        GBtn(tr("pj.edit"), { app.push(Route.NewProject(p.id)) }, Btn.SECONDARY, icon = "edit")
    }
}

@Composable
private fun Kv(label: String, value: String, extra: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f)) {
            Text(label, style = ui(12.5f, 400, G.ink2))
            Text(value, style = ui(15.5f, 500))
        }
        extra?.invoke()
    }
}

/* ---------------- Quotes tab (prototype quotesTab) ---------------- */

@Composable
private fun QuotesTab(p: Project, lang: Lang) {
    val app = LocalApp.current
    if (p.isFurniture) FIssueBar(p, lang)
    if (p.quotes.isEmpty() && p.isFurniture) return
    if (p.quotes.isEmpty()) {
        Column(
            Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(Modifier.size(56.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("doc", G.cobalt, 26.dp, 2f) }
            Text(tr("q.emptyTitle"), style = ui(18f, 700), textAlign = TextAlign.Center)
            Text(tr(if (p.isFurniture) "fd.qEmpty" else "q.emptyBody"), style = ui(14f, 400, G.ink2, 1.45f), textAlign = TextAlign.Center)
            GBtn(tr(if (p.isFurniture) "fo.price" else "pr.estimate"), { app.setProjectTab(if (p.isFurniture) "price" else "estimate") }, Btn.SECONDARY, fill = false)
        }
        return
    }
    // a furniture order's snapshot prices every piece: worked out again only when the order or the settings change
    val now = androidx.compose.runtime.remember(p, app.settings.unit, app.settings.builderName, app.settings.builderPhone, app.settings.pdf, app.settings.angleSnap, app.settings.workshop, app.settings.mats, app.settings.hws) { uz.metrx.app.report.fingerprint(uz.metrx.app.report.snapshotOf(p, app.settings)) }
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        p.quotes.reversed().forEach { q ->
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).pressable({ app.push(Route.Quote(p.id, q.no)) }).padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("q.no", "n" to q.no), style = ui(17f, 600), modifier = Modifier.weight(1f))
                    MIcon("lock", G.ink2, 14.dp, 2f); Text(" " + tr("q.issued"), style = ui(13.5f, 400, G.ink2))
                }
                Text(uz.metrx.app.data.fmtDate(q.ts) + ", " + uz.metrx.app.ui.report.fmtTime(q.ts) + ". " + tr("q.lang", "l" to Lang.of(q.sn.lang).longName), style = ui(13.5f, 400, G.ink2, 1.35f))
                Text(if (q.sn.furniture.isNotEmpty()) q.sn.furniture.joinToString(" + ") { uz.metrx.app.data.dn(it.name, lang) } else tr("q.rooms", "n" to q.sn.rooms.size), style = ui(13.5f, 400, G.ink2))
                Column(Modifier.padding(top = 6.dp)) {
                    Hairline()
                    Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(tr("es.grand"), style = ui(14f, 400), modifier = Modifier.weight(1f))
                        Text(uz.metrx.app.core.moneyStr(java.math.BigInteger(q.total), q.sn.precision, lang == Lang.EN) + " " + uz.metrx.app.core.curSuffix(q.sn.currency, lang), style = ui(14f, 700))
                    }
                }
                Column(Modifier.padding(top = 6.dp)) {
                    Hairline()
                    Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        val same = q.fp == now
                        MIcon(if (same) "check" else "info", G.ink, 14.dp, 2.2f)
                        Text(tr(if (same) "q.same" else "q.differs"), style = ui(14f, 400))
                    }
                }
            }
        }
    }
}

/** Tabs that arrive in later parts say so plainly. */
@Composable
private fun LaterTab(icon: String, part: Int) {
    Column(
        Modifier.padding(start = 16.dp, end = 16.dp, top = 14.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(Modifier.size(56.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon(icon, G.cobalt, 26.dp, 2f) }
        Text(tr("nt.part", "n" to part), style = ui(15f, 600, G.ink2), textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 280.dp))
    }
}

fun openMap(context: android.content.Context, p: Project) {
    val l = p.location ?: return
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=${l.lat},${l.lng}"))) }
}

/** A furniture order's Quotes tab starts with issuing the next quote at today's price, and looking at the PDF first. */
@Composable
private fun FIssueBar(p: Project, lang: Lang) {
    val app = LocalApp.current
    val st = app.settings
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    val price = androidx.compose.runtime.remember(p.furniture, p.fprice, st.workshop, st.mats, st.hws) { uz.metrx.app.furniture.priceOf(fs, p.fprice, st.workshop, st.mats, st.hws).price }
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (fs.isEmpty()) {
            Text(tr("fp.empty"), style = ui(14f, 400, G.ink2, 1.45f), textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(20.dp))
            return@Column
        }
        val (v, u) = uz.metrx.app.core.shortMoney(p, price, lang == Lang.EN, tr("pl.mln"))
        // a new quote only when something changed since the last one: otherwise it would be the same quote again
        val last = p.quotes.lastOrNull()
        val fp = androidx.compose.runtime.remember(p, app.settings.unit, app.settings.builderName, app.settings.builderPhone, app.settings.pdf, app.settings.angleSnap, app.settings.workshop, app.settings.mats, app.settings.hws) { uz.metrx.app.report.fingerprint(uz.metrx.app.report.snapshotOf(p, app.settings)) }
        val changed = last == null || last.fp != fp
        if (changed) GBtn(tr("fo.issueN", "n" to p.quotes.size + 1, "v" to v + (u?.let { " $it" } ?: "")), { app.sheet = Sheet.Issue(p.id) }, icon = "lock", maxLines = 2)
        GBtn(tr("fo.preview"), { app.push(Route.Report(p.id)) }, Btn.SECONDARY, icon = "doc", height = 46.dp, fontSize = 14.5f)
    }
}
