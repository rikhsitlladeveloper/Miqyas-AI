package uz.metrx.app.ui.main

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.core.Phone
import uz.metrx.app.ui.components.GlassButton
import uz.metrx.app.ui.components.GlassHeader
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.LaserButton
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalSettings
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

enum class Tab(val icon: String, val label: String) { HOME("home", "tab.home"), PROJECTS("folder", "tab.projects"), PROFILE("user", "tab.profile") }

/** What the main screens ask the app to do. */
interface MainNav {
    fun laser()
    fun newProject()
    fun measure()
    fun calculator()
    fun languages()
    fun signIn()
}

/** Space the floating tab bar takes at the bottom of every tab page (68 + margins 4 and 14). */
val NAV_SPACE = 86.dp

/** The floating three-tab bar (prototype .gl-nav): a glass pill, the current tab a white bubble. */
@Composable
fun GlassNav(cur: Tab, onTab: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(34.dp)
    Box(modifier.fillMaxWidth().navigationBarsPadding().padding(top = 4.dp, bottom = 14.dp), contentAlignment = Alignment.Center) {
        Row(
            Modifier.widthIn(max = 300.dp).fillMaxWidth().padding(horizontal = 20.dp).let { it }
                .height(68.dp)
                .dropShadow(shape, Shadow(34.dp, G.shade.copy(alpha = .18f), offset = DpOffset(0.dp, 14.dp)))
                .clip(shape).glassBlur(haze, G.sheet(.45f), 26.dp).topHighlight()
                .border(1.dp, G.rim, shape).padding(6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            val furniture = LocalSettings.current.furniture || LocalSettings.current.tiler
            Tab.entries.forEach { t ->
                val on = t == cur
                val label = if (t == Tab.PROJECTS && furniture) "fo.tab" else t.label
                val bg by animateColorAsState(if (on) G.glass(.85f) else Color.Transparent, label = "tab")
                val bubble = RoundedCornerShape(28.dp)
                Column(
                    Modifier.weight(1f).fillMaxSize()
                        .let { if (on) it.dropShadow(bubble, Shadow(12.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 4.dp))) else it }
                        .clip(bubble).background(bg)
                        .semantics { selected = on }
                        .clickable(role = Role.Tab) { onTab(t) },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)
                ) {
                    MIcon(t.icon, if (on) G.cobalt2 else G.slate, 22.dp, 2f)
                    Text(tr(label), style = ui(11f, if (on) 700 else 600, if (on) G.cobalt2 else G.slate), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

private const val PLAN = "M10 10h120v60h50v70H10z M10 80h70 M80 80v60 M130 10v60"
private const val PLAN_DIM = "M40 10v-6 M100 10v-6 M40 7h60"
private const val ARROW = "M7 17L17 7M9 7h8v8"
private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private const val CALC = "M8 2.5h8a3 3 0 0 1 3 3v13a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3v-13a3 3 0 0 1 3-3z M8.5 6.5h7M8.5 11h.01M12 11h.01M15.5 11h.01M8.5 14.5h.01M12 14.5h.01M15.5 14.5h.01M8.5 18h.01M12 18h.01M15.5 18h.01"

/** Home: a greeting with a different line on every visit, one big "New project" card and two small cards. */
@Composable
fun HomeScreen(nav: MainNav) {
    val settings = LocalSettings.current
    if (settings.furniture) { uz.metrx.app.ui.furniture.FurnitureHome(nav); return }
    if (settings.tiler) { uz.metrx.app.ui.tiles.TilerHome(nav); return }
    val first = settings.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("gl.lines").split('|')
    val line = lines[settings.visit % lines.size]
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        GlassHeader(nav::laser)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp + NAV_SPACE).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(Modifier.padding(top = 22.dp, bottom = 16.dp)) {
                Text(if (first.isNotEmpty()) tr("hm.hi", "n" to first) else tr("hm.hi0"), style = ui(38f, 800, G.ink, 1.1f, -.02f))
                Text(line, style = ui(19f, 500, G.slate, 1.35f), modifier = Modifier.padding(top = 10.dp).widthIn(max = 320.dp))
            }
            BigCard(nav::newProject)
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                SmallCard(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                SmallCard(CALC, tr("gl.calc"), tr("gl.calcS"), nav::calculator, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun BigCard(onClick: () -> Unit) {
    val shape = RoundedCornerShape(34.dp)
    val plan = androidx.compose.runtime.remember { PathParser().parsePathString(PLAN).toPath() to PathParser().parsePathString(PLAN_DIM).toPath() }
    Box(
        Modifier.fillMaxWidth().heightIn(min = 250.dp)
            .glassCard(shape, shadowRadius = 40.dp, shadowY = 18.dp, shadowAlpha = .16f)
            .drawWithContent { drawContent(); drawRect(G.hi(.35f), topLeft = Offset(0f, size.height - 1.dp.toPx()), size = size.copy(height = 1.dp.toPx())) }
            .pressable(onClick)
    ) {
        Canvas(Modifier.align(Alignment.TopEnd).offset(x = 14.dp, y = 18.dp).size(190.dp, 150.dp).alpha(.35f)) {
            val k = size.width / 190f
            scale(k, k, pivot = Offset.Zero) {
                drawPath(plan.first, G.cobalt, style = Stroke(2f))
                drawPath(plan.second, G.cobalt, style = Stroke(1.2f))
            }
        }
        Column(Modifier.padding(22.dp).heightIn(min = 206.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Box(
                Modifier.size(64.dp).dropShadow(RoundedCornerShape(22.dp), Shadow(24.dp, G.cobalt.copy(alpha = .4f), offset = DpOffset(0.dp, 10.dp)))
                    .clip(RoundedCornerShape(22.dp)).background(G.cobalt).topHighlight(.45f),
                contentAlignment = Alignment.Center
            ) { MIcon("plus", Color.White, 30.dp, 2.4f) }
            Row(Modifier.fillMaxWidth().padding(top = 28.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(tr("hm.t.new"), style = ui(30f, 800, G.ink, 1.1f, -.02f))
                    Text(tr("gl.newS"), style = ui(15f, 400, G.ink2))
                }
                Box(Modifier.size(44.dp).clip(CircleShape).background(G.glass(.7f)), contentAlignment = Alignment.Center) {
                    PathIcon(ARROW, G.ink, 20.dp, 2.2f)
                }
            }
        }
    }
}

@Composable
private fun SmallCard(icon: String, title: String, sub: String, onClick: () -> Unit, modifier: Modifier) {
    Column(
        modifier.heightIn(min = 150.dp).glassCard(RoundedCornerShape(28.dp)).pressable(onClick).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.Top)
    ) {
        Box(Modifier.size(46.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) {
            PathIcon(icon, G.cobalt, 22.dp, 2f)
        }
        Spacer(Modifier.weight(1f, fill = false))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = ui(18f, 700))
            Text(sub, style = ui(13f, 400, G.ink2))
        }
    }
}

/** Big page title of the tab pages (prototype .h1). */
@Composable
fun PageTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, style = ui(36f, 800, G.ink, 1.15f, -.02f), modifier = modifier)
}

/** Projects with no project yet: one card that invites the first one (prototype plEmpty). */
@Composable
fun ProjectsEmpty(onNew: () -> Unit) {
    Column(Modifier.verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 24.dp + NAV_SPACE).navigationBarsPadding()) {
        Column(
            Modifier.fillMaxWidth().glassCard(RoundedCornerShape(26.dp), fill = G.glass(.55f)).padding(start = 22.dp, end = 22.dp, top = 34.dp, bottom = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(Modifier.padding(bottom = 8.dp)) {
                Box(Modifier.size(88.dp).clip(RoundedCornerShape(26.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) {
                    MIcon("folder", G.cobalt, 40.dp, 1.8f)
                }
                Box(Modifier.align(Alignment.TopEnd).offset(9.dp, (-9).dp).size(34.dp).clip(CircleShape).background(G.solid.copy(alpha = .9f)).padding(3.dp).clip(CircleShape).background(G.cobalt), contentAlignment = Alignment.Center) {
                    MIcon("plus", Color.White, 16.dp, 2.4f)
                }
            }
            Text(tr("pl.e.t"), style = ui(21f, 800, G.ink, 1.2f, -.01f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Text(tr("pl.e.b"), style = ui(15f, 400, G.ink2, 1.5f), textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.widthIn(max = 300.dp).padding(bottom = 10.dp))
            GlassButton(tr("pl.e.new"), onNew, icon = "plus")
        }
        Text(tr("pl.e.foot"), style = ui(13.5f, 400, G.ink3), textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    }
}

/** Profile, part 1: who you are, the app language and sign-in. Report, measuring and Pro settings arrive in part 7. */
/** App language (prototype SHEETS.lang). */
@Composable
fun LanguageSheet(cur: Lang, onPick: (Lang) -> Unit, onClose: () -> Unit) {
    GlassSheet(tr("se.lang"), onClose) {
        Lang.entries.forEach { l ->
            val on = l == cur
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp))
                    .background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
                    .border(1.dp, if (on) G.cobalt.copy(alpha = .5f) else G.idleRim, RoundedCornerShape(16.dp))
                    .clickable(role = Role.RadioButton) { onPick(l) }.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(l.longName, style = ui(16f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f))
                if (on) MIcon("check", G.cobalt2, 20.dp, 2.4f)
            }
        }
    }
}

/**
 * The measuring device (prototype SHEETS.device). There is no real laser yet: searching finds the simulator,
 * which the sheet says plainly. Typing values always works.
 */
@Composable
fun DeviceSheet(onClose: () -> Unit, onSearch: () -> Unit, onConnect: () -> Unit, onDisconnect: () -> Unit) {
    val settings = LocalSettings.current
    val st = settings.laser
    GlassSheet(tr("dv.title"), onClose, footer = {
        when (st) {
            Laser.CONNECTED -> GlassButton(tr("dv.disconnect"), onDisconnect, primary = false)
            Laser.FOUND -> GlassButton(tr("dv.connect"), onConnect)
            Laser.SEARCHING -> {}
            Laser.DISCONNECTED -> GlassButton(tr("dv.search"), onSearch, icon = "search")
        }
    }) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(tr("dv.status"), style = ui(14f, 500, G.ink2), modifier = Modifier.weight(1f))
            Text(tr(when (st) { Laser.SEARCHING -> "dev.scan"; Laser.CONNECTED -> "dev.conn"; else -> "dev.disc" }), style = ui(14f, 700, if (st == Laser.CONNECTED) G.green else G.ink))
        }
        if (st == Laser.FOUND || st == Laser.CONNECTED) {
            if (st == Laser.FOUND) Text(tr("dv.found"), style = ui(13f, 700, G.ink3))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(vertical = 4.dp)) {
                MIcon("laser", G.cobalt, 24.dp, 2f)
                Column {
                    Text(tr("dv.simDev"), style = ui(15.5f, 700))
                    Text(tr("nt.simLaser"), style = ui(13f, 500, G.amberInk))
                }
            }
        }
        if (st == Laser.SEARCHING) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(vertical = 8.dp)) {
            MIcon("search", G.cobalt, 26.dp, 2f); Text(tr("dev.scan"), style = ui(15.5f, 700))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("kbd", G.ink2, 18.dp, 2f); Text(tr("dv.always"), style = ui(13f, 400, G.ink2, 1.4f))
        }
    }
}
