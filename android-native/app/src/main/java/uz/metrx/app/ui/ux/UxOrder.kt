package uz.metrx.app.ui.ux

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.F_STAGES
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.fStage
import uz.metrx.app.data.fmtDate
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * A furniture order (UX upgrades §1, §2, §4): no tab bar; Back and the order's name on top with the progress bar and
 * the price; two tabs, Mebel and Ma’lumot (the client and the 7 production stages); one next-step button and Undo at the bottom.
 */

@Composable
fun FOrderScreen(r: Route.Project, p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ctx = LocalContext.current
    // the old tabs' links (the designers' price bar, a quote just issued) open the price screen, over the order
    LaunchedEffect(r.tab) {
        if (r.tab == "price" || r.tab == "quotes") { app.setTop(r.copy(tab = "rooms")); app.push(Route.FPrice(p.id)) }
    }
    val tab = if (r.tab == "info") "info" else "rooms"
    val act = app.fNextAct(p, ctx)
    val galleryNext = act.label == app.t("ux.a.addFurn") || act.label == app.t("ux.a.more")
    Column(Modifier.fillMaxSize()) {
        UxTop(dn(p.name, lang), { app.pop() }, eyebrow = tr("ux.order"), right = {
            uz.metrx.app.ui.furniture.CallButton(p)
            Box(Modifier.size(46.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button, onClickLabel = tr("common.menu")) {
                app.sheet = Sheet.ProjectMenu(p.id)
            }, contentAlignment = Alignment.Center) { MIcon("more", G.ink, 20.dp, 2f) }
        }) {
            ProgressRow(p)
            PriceLine(p)
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
            Box(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp)) {
                UxSeg(listOf("rooms" to tr("ux.tab.furn"), "info" to tr("pj.info")), tab) { app.setProjectTab(it) }
            }
            if (tab == "info") InfoPart(p, lang)
            else if (r.view != "list" && p.rooms.isNotEmpty()) Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp)) {
                uz.metrx.app.ui.projects.ViewSeg(r.view) { app.setTop(r.copy(view = it)) }
                if (r.view == "2d") uz.metrx.app.ui.projects.Plans2D(p, lang) else uz.metrx.app.ui.projects.Project3D(p, r, lang)
            } else FurnPart(p, lang, r, !galleryNext)
        }
        UxBar(act.label, act.icon, act.go, onUndo = { app.undoLast() }, canUndo = app.undos.isNotEmpty(), coach = "order")
    }
}

/** The Mebel tab: an empty order says where to start; otherwise its rooms with their furniture. */
@Composable
private fun FurnPart(p: Project, lang: Lang, r: Route.Project, addCard: Boolean) {
    val app = LocalApp.current
    if (p.furniture.isEmpty() && p.floors.isEmpty()) {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.size(56.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("cube", G.cobalt, 26.dp, 2f) }
                Text(tr("ux.empty.t"), style = ui(17f, 800), textAlign = TextAlign.Center)
                Text(tr("ux.empty.b"), style = ui(14f, 400, G.ink2, 1.45f), textAlign = TextAlign.Center)
                UxIcon("down", G.cobalt, 26.dp, 2.4f)
            }
            uz.metrx.app.ui.rooms.StartPaths(p)
        }
        return
    }
    uz.metrx.app.ui.furniture.FRoomsTab(p, lang, r, addCard = addCard)
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // (room-less pieces have their own card above, FreeCard)
        p.quotes.lastOrNull()?.let { q ->
            InfoRow("lock", tr("ux.sentRow", "n" to q.no), tr("ux.sentRowS", "d" to fmtDate(q.ts) + " " + uz.metrx.app.ui.report.fmtTime(q.ts))) { app.push(Route.FPrice(p.id)) }
        }
    }
}

/** A grey row with an icon, a title and a line (the order's room state, the quote sent). */
@Composable
internal fun InfoRow(icon: String, title: String, sub: String, onClick: (() -> Unit)?) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp))
        .let { if (onClick != null) it.clickable(role = Role.Button, onClick = onClick) else it }.padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MIcon(icon, G.ink2, 20.dp, 2f)
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(14.5f, 700))
            Text(sub, style = ui(12.5f, 400, G.ink2, 1.35f))
        }
        if (onClick != null) MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

/** The Ma’lumot tab: the client, then the 7 production stages (Advanced changes them, with the payments). */
@Composable
private fun InfoPart(p: Project, lang: Lang) {
    val app = LocalApp.current
    if (app.settings.advanced) Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f))
        .padding(horizontal = 14.dp, vertical = 6.dp)) { uz.metrx.app.ui.furniture.FNums(p) }
    uz.metrx.app.ui.projects.InfoTab(p, lang)
    if (app.settings.advanced) uz.metrx.app.ui.furniture.FurnitureInfo(p)
    else {
        // the simple app sees where the order is; Advanced moves it on
        val k = fStage(p)
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("ux.stagesT"), style = ui(15f, 800), modifier = Modifier.weight(1f))
                Text("${k + 1} / ${F_STAGES.size}", style = ui(12.5f, 600, G.ink2))
            }
            F_STAGES.forEachIndexed { i, st ->
                val done = i < k; val cur = i == k
                Row(Modifier.fillMaxWidth().heightIn(min = 34.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(24.dp).clip(CircleShape).background(if (done) G.cobalt else if (cur) G.solid else Color.Transparent)
                        .border(2.dp, if (done || cur) G.cobalt else G.ink3.copy(alpha = .35f), CircleShape), contentAlignment = Alignment.Center) {
                        if (done) MIcon("check", Color.White, 12.dp, 3f) else Text("${i + 1}", style = ui(11.5f, 800, if (cur) G.cobalt2 else G.ink3))
                    }
                    Text(tr("fs.$st"), style = ui(14f, if (cur) 800 else 600, if (i > k) G.ink3 else G.ink))
                }
            }
            Text(tr("ux.adv.stages"), style = ui(12.5f, 400, G.ink2, 1.4f), modifier = Modifier.padding(top = 4.dp))
        }
    }
}
