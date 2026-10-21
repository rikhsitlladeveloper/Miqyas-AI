package uz.metrx.app.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.core.Phone
import uz.metrx.app.data.PdfParts
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.LaserButton
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Profile (prototype profile.js "status first, short groups" with the glass Pro card) and its "More settings" page,
 * the subscription page and the settings sheets. Dark mode is this app's own addition (founder's decision).
 */

private val GOLD = Color(0xFFF5C451)

@Composable
fun ProfileScreen(nav: MainNav, onEditMe: () -> Unit) {
    val app = LocalApp.current
    val s = app.settings
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val name = s.builderName
    val initials = name.split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2).joinToString("") { it.take(1) }.uppercase().ifEmpty { "?" }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 16.dp, top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            PageTitle(tr("tab.profile"), Modifier.weight(1f).padding(start = 16.dp, top = 6.dp))
            LaserButton(nav::laser)
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 2.dp, bottom = 20.dp + NAV_SPACE).navigationBarsPadding()) {
            // who appears on every quote
            Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().glassCard(RoundedCornerShape(18.dp), fill = G.glass(.55f))) {
                Row(Modifier.fillMaxWidth().pressable(onEditMe, .99f).padding(start = 12.dp, end = 12.dp, top = 12.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(56.dp).clip(CircleShape).background(G.avatar), contentAlignment = Alignment.Center) { Text(initials, style = ui(20f, 600, Color.White)) }
                    Column(Modifier.weight(1f)) {
                        Text(name.ifEmpty { tr("prof.noName") }, style = ui(17f, 600, G.ink, 1.25f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(if (s.builderPhone.isNotEmpty()) Phone.format(s.builderPhone) else tr("se.notSet"), style = ui(13.5f, 400, G.ink2, 1.25f))
                    }
                    Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)), contentAlignment = Alignment.Center) { MIcon("edit", G.ink, 18.dp, 2f) }
                }
                Row(Modifier.fillMaxWidth().topRule().padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
                    MIcon("doc", G.ink2, 16.dp, 2f); Text(tr("pf.onQuote"), style = ui(12.5f, 400, G.ink2, 1.4f))
                }
            }
            ProCard { app.push(Route.Subscription) }
            // furniture makers: how the workshop builds and prices, and its boards and hardware (furniture plan section 6)
            if (s.furniture) {
                Group(tr("wk.group"))
                Card {
                    // off: the app is just the 3D design; on: prices, order stages, workshop rules, cutting lists
                    SwitchRow("sliders", tr("adv.title"), s.advanced) { s.setAdvancedOn(!s.advanced); app.say(if (s.advanced) "adv.on" else "adv.off") }
                    if (s.advanced) {
                        Row1("board", tr("wk.title"), null, sub = tr("wk.titleS")) { app.push(Route.Workshop) }
                        Row1("layers", tr("wk.mats"), null, sub = tr("wk.matsS", "m" to s.mats.size, "h" to s.hws.size)) { app.push(Route.Materials) }
                    }
                }
                Text(tr("adv.sub"), style = ui(12.5f, 400, G.ink2, 1.4f), modifier = Modifier.padding(start = 28.dp, end = 28.dp, top = 8.dp))
            }
            Group(tr("pf.gReport"))
            Card {
                Row1("sliders", tr("ind.row"), tr(when { s.furniture -> "ind.furn"; uz.metrx.app.trades.isTrade(s.industry) -> "ind.${s.industry}"; else -> "ind.build" })) { app.sheet = Sheet.Industry }
                Row1("globe", tr("se.lang"), s.lang.longName) { nav.languages() }
                Row1("doc", tr("se.reportLang"), s.reportLang.longName) { app.sheet = Sheet.ReportLang }
                val pdfN = listOf(s.pdf.plan, s.pdf.dims, s.pdf.views, s.pdf.estimate, s.pdf.sign).count { it }
                Row1("layers", tr("se.pdf"), "$pdfN/5") { app.sheet = Sheet.PdfParts }
                Row1("coin", tr("np.currency"), s.currency) { app.sheet = Sheet.Currency }
            }
            // dark mode: this app's own (the prototype has only the light look)
            Card(Modifier.padding(top = 10.dp)) { SwitchRow("moon", tr("nt.dark"), s.dark) { s.setDarkMode(!s.dark) } }
            Group(tr("pf.gMeasure"))
            Card {
                Row1("door", tr("se.defaults"), fmtLen(s.doorW, s.unit, en) + " × " + fmtLen(s.doorH, s.unit, en)) { app.sheet = Sheet.Defaults }
                SwitchRow("ruler", tr("se.snap"), s.angleSnap) { s.setSnap(!s.angleSnap) }
            }
            Group(tr("ac.group"))
            Card { Row1("user", tr("ac.signIn"), null, sub = tr("ac.noneB")) { nav.signIn() } }
            val shape = RoundedCornerShape(14.dp)
            Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 14.dp).fillMaxWidth().height(52.dp).glassCard(shape, fill = G.glass(.55f)).pressable({ app.push(Route.SettingsMore) }, .99f)
                .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MIcon("sliders", G.ink, 18.dp, 2f); Text(tr("pf.more"), style = ui(15f, 600), modifier = Modifier.weight(1f)); MIcon("chev", G.ink2, 18.dp, 2f)
            }
            Row(Modifier.padding(start = 18.dp, end = 18.dp, top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon("device", G.ink2, 16.dp, 2f); Text(tr("prof.local"), style = ui(12.5f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f))
            }
        }
    }
}

private fun Modifier.topRule() = drawBehind { drawLine(G.rim, Offset(0f, 0f), Offset(size.width, 0f), .67.dp.toPx()) }

/** METRX Pro: active during the pilot, everything open (glass .gl-pro: deep violet, a gold rim and a sheen). */
@Composable
private fun ProCard(onClick: () -> Unit) {
    val shape = RoundedCornerShape(28.dp)
    Column(
        Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp).fillMaxWidth()
            .dropShadow(shape, Shadow(40.dp, Color(0x613C288C), offset = DpOffset(0.dp, 18.dp)))
            .drawBehind { drawRoundRect(GOLD.copy(alpha = .12f), Offset(-4.dp.toPx(), -4.dp.toPx()), androidx.compose.ui.geometry.Size(size.width + 8.dp.toPx(), size.height + 8.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(32.dp.toPx())) }
            .clip(shape).background(Brush.linearGradient(listOf(Color(0xFF171B45), Color(0xFF2B2A78), Color(0xFF52309A)), start = Offset(0f, 0f), end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)))
            .drawBehind {
                // the sheen: a soft light band across the card
                val band = Path().apply { moveTo(size.width * .1f, 0f); lineTo(size.width * .45f, 0f); lineTo(size.width * .25f, size.height); lineTo(-size.width * .1f, size.height); close() }
                clipPath(band) { drawRect(Brush.horizontalGradient(listOf(Color.White.copy(alpha = 0f), Color.White.copy(alpha = .1f), Color.White.copy(alpha = 0f)))) }
            }
            .border(.67.dp, GOLD.copy(alpha = .6f), shape).pressable(onClick, .99f).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(46.dp).clip(RoundedCornerShape(16.dp)).background(GOLD.copy(alpha = .18f)), contentAlignment = Alignment.Center) { MIcon("card", GOLD, 22.dp, 2f) }
            Column {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("METRX Pro", style = ui(19f, 800, Color.White))
                    Text(tr("pf.subOn"), style = ui(12f, 700, Color(0xFF7BE3A9)), modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(Color(0x2E3DD68C)).padding(horizontal = 9.dp, vertical = 3.dp))
                }
                Text(tr("gl.proOn"), style = ui(13f, 400, Color(0xFFD4D7F7)))
            }
        }
        Row(Modifier.fillMaxWidth().drawBehind { drawLine(Color.White.copy(alpha = .14f), Offset(0f, 0f), Offset(size.width, 0f), .67.dp.toPx()) }.padding(top = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(tr("sub.pilot"), style = ui(13f, 400, Color(0xFFD4D7F7), 1.4f), modifier = Modifier.weight(1f))
            Text(tr("gl.manage"), style = ui(14f, 700, GOLD)); MIcon("chev", GOLD, 14.dp, 2.4f)
        }
    }
}

@Composable
private fun Group(text: String) = Text(text, style = ui(13f, 500, G.ink2), modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 8.dp))

@Composable
private fun Card(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(modifier.padding(horizontal = 20.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f))) { content() }
}

@Composable
private fun IconTile(icon: String) = Box(Modifier.size(36.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) {
    if (icon == "moon") uz.metrx.app.ui.icons.PathIcon("M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z", G.cobalt, 20.dp, 2f) else MIcon(icon, G.cobalt, 20.dp, 2f)
}

/** A settings row (prototype .listrow): icon tile, title, its value, a chevron. */
@Composable
private fun Row1(icon: String, title: String, value: String?, sub: String? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.Button, onClick = onClick).padding(start = 12.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        IconTile(icon)
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15.5f, 500, G.ink, 1.4f))
            if (sub != null) Text(sub, style = ui(13f, 400, G.ink2, 1.35f))
        }
        if (value != null) Text(value, style = ui(14f, 400, G.ink2), maxLines = 1)
        MIcon("chev", G.ink2, 18.dp, 2f)
    }
}

@Composable
private fun SwitchRow(icon: String, title: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.Switch, onClick = onClick).padding(start = 12.dp, end = 14.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        IconTile(icon); Text(title, style = ui(15.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f)); GSwitch(on)
    }
}

/** A page with a back button and a title (the bar of prototype pages that are not tabs). */
@Composable
private fun SubPage(title: String, content: @Composable () -> Unit) {
    val app = LocalApp.current
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }); Text(title, style = ui(17f, 700), modifier = Modifier.weight(1f))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { content() }
    }
}

/** Profile → More settings (prototype PAGES.settingsMore). */
@Composable
fun SettingsMoreScreen() {
    val app = LocalApp.current
    val s = app.settings
    SubPage(tr("pf.more")) {
        Card {
            Row1("ruler", tr("se.units"), tr(if (s.unit == LenUnit.CM) "un.cm" else "un.m")) { app.sheet = Sheet.Units }
            Row1("room", tr("se.label"), tr("se.label." + s.roomLabel)) { app.sheet = Sheet.RoomLabel }
            Row1("info", tr("se.hintsReset"), null) { s.resetHints(); app.ops.tipSeen = false; app.say("se.hintsDone") }
        }
        Card {
            Row1("bt", tr("se.device"), tr(if (s.laser == Laser.CONNECTED) "pf.btOn" else "pf.btDisc")) { app.sheet = Sheet.Device }
            Row1("card", tr("se.sub"), tr("se.active")) { app.push(Route.Subscription) }
        }
        Card { Row1("info", tr("se.about"), null) { app.sheet = Sheet.About } }
    }
}

/** METRX Pro (prototype PAGES.sub): active in the pilot; what keeps working and what would need a subscription. */
@Composable
fun SubscriptionScreen() {
    SubPage(tr("se.sub")) {
        Card {
            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("dv.status"), style = ui(14f, 400, G.ink2), modifier = Modifier.weight(1f)); Text(tr("se.active"), style = ui(15f, 700))
            }
        }
        Text(tr("sub.pilot"), style = ui(14f, 400, G.ink2, 1.45f), modifier = Modifier.padding(horizontal = 24.dp))
        Group(tr("sub.works"))
        Card { listOf("sub.w1", "sub.w2", "sub.w4").forEachIndexed { i, k -> if (i > 0) Hairline(); Li("check", tr(k), G.green) } }
        Group(tr("sub.locked"))
        Card { listOf("sub.l1", "sub.l2", "sub.l3").forEachIndexed { i, k -> if (i > 0) Hairline(); Li("lock", tr(k), G.ink2) } }
    }
}

@Composable
private fun Li(icon: String, text: String, tint: Color) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MIcon(icon, tint, 20.dp, 2.2f); Text(text, style = ui(15f, 500))
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun ProfileSheet(s: Sheet): Boolean = when (s) {
    Sheet.ReportLang, Sheet.PdfParts, Sheet.Defaults, Sheet.Units, Sheet.RoomLabel, Sheet.About -> { ProfileSheetUi(s); true }
    else -> false
}

@Composable
private fun ProfileSheetUi(s: Sheet) {
    when (s) {
        Sheet.ReportLang -> ReportLangSheet()
        Sheet.PdfParts -> PdfSheet()
        Sheet.Defaults -> DefaultsSheet()
        Sheet.Units -> UnitsSheet()
        Sheet.RoomLabel -> RoomLabelSheet()
        Sheet.About -> AboutSheet()
        else -> {}
    }
}

/** A choice in a list (prototype .optlist .opt): white, blue when chosen, with a check. */
@Composable
private fun Opt(title: String, on: Boolean, sub: String? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
        .border(1.dp, if (on) G.cobalt.copy(alpha = .5f) else G.idleRim, RoundedCornerShape(16.dp)).clickable(role = Role.RadioButton, onClick = onClick).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(16f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink))
            if (sub != null) Text(sub, style = ui(13f, 400, G.ink2))
        }
        if (on) MIcon("check", G.cobalt2, 20.dp, 2.4f)
    }
}

@Composable
private fun ReportLangSheet() {
    val app = LocalApp.current
    GlassSheet(tr("se.reportLang"), { app.sheet = null }) {
        Lang.entries.forEach { l -> Opt(l.longName, app.settings.reportLang == l) { app.settings.setReportLangDefault(l); app.sheet = null } }
    }
}

@Composable
private fun PdfSheet() {
    val app = LocalApp.current
    val p = app.settings.pdf
    GlassSheet(tr("se.pdf"), { app.sheet = null }) {
        listOf("plan" to p.plan, "dims" to p.dims, "views" to p.views, "estimate" to p.estimate, "sign" to p.sign).forEach { (k, on) ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).clickable(role = Role.Checkbox) {
                app.settings.setPdfParts(when (k) { "plan" -> p.copy(plan = !on); "dims" -> p.copy(dims = !on); "views" -> p.copy(views = !on); "estimate" -> p.copy(estimate = !on); else -> p.copy(sign = !on) })
            }.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon(if (on) "boxok" else "box", if (on) G.cobalt else G.ink2, 24.dp, 2f); Text(tr("pdf.$k"), style = ui(16f, 500))
            }
        }
        Text(tr("se.pdfBody"), style = ui(13f, 400, G.ink2, 1.45f))
    }
}

@Composable
private fun UnitsSheet() {
    val app = LocalApp.current
    GlassSheet(tr("se.units"), { app.sheet = null }) {
        listOf(LenUnit.M to "m", LenUnit.CM to "cm").forEach { (u, k) -> Opt(tr("un.$k"), app.settings.unit == u, tr("un.${k}Ex")) { app.settings.changeUnit(u) } }
        Text(tr("un.note"), style = ui(13f, 400, G.ink2, 1.45f))
    }
}

@Composable
private fun RoomLabelSheet() {
    val app = LocalApp.current
    GlassSheet(tr("se.label"), { app.sheet = null }) {
        listOf("both", "name", "area", "none").forEach { k -> Opt(tr("se.label.$k"), app.settings.roomLabel == k) { app.settings.setRoomLabelMode(k); app.sheet = null } }
    }
}

@Composable
private fun AboutSheet() {
    val app = LocalApp.current
    GlassSheet(tr("se.about"), { app.sheet = null }, footer = { GBtn(tr("common.close"), { app.sheet = null }, uz.metrx.app.ui.components.Btn.SECONDARY) }) {
        Text(tr("se.aboutBody"), style = ui(15f, 400, G.ink, 1.45f))
        val c = androidx.compose.ui.platform.LocalContext.current
        val v = runCatching { c.packageManager.getPackageInfo(c.packageName, 0).versionName }.getOrNull()
        if (v != null) Text("METRX $v", style = ui(13f, 400, G.ink2))
    }
}

/** Default door and window sizes (prototype SHEETS.defaults): typed with the length rules of the room editor. */
@Composable
private fun DefaultsSheet() {
    val app = LocalApp.current
    val s = app.settings
    val en = LocalLang.current == Lang.EN
    val u = s.unit
    var dw by rememberSaveable { mutableStateOf(fmtField(s.doorW, u, en)) }; var dh by rememberSaveable { mutableStateOf(fmtField(s.doorH, u, en)) }
    var ww by rememberSaveable { mutableStateOf(fmtField(s.winW, u, en)) }; var wh by rememberSaveable { mutableStateOf(fmtField(s.winH, u, en)) }
    var ws by rememberSaveable { mutableStateOf(fmtField(s.winSill, u, en)) }
    var tried by remember { mutableStateOf(false) }
    fun chk(v: String, max: Int, zeroOk: Boolean = false) = lenErr(v, max, u, en, zeroOk)
    // a window can sit on the floor: its sill may be 0
    val r = listOf(chk(dw, 100_000), chk(dh, 20_000), chk(ww, 100_000), chk(wh, 20_000), chk(ws, 20_000, zeroOk = true))
    val errs = r.map { uz.metrx.app.ui.editor.errText(it) }
    fun err(i: Int) = errs[i]
    val m = tr(if (u == LenUnit.CM) "u.cm" else "u.m")
    GlassSheet(tr("se.defaults"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if (r.any { it !is Parsed.Ok }) { tried = true; return@GBtn }
            val v = r.map { (it as Parsed.Ok).value.toInt() }
            s.setDefaults(v[0], v[1], v[2], v[3], v[4]); app.sheet = null; app.say("se.saved")
        })
    }) {
        Text(tr("se.defaultsBody"), style = ui(14f, 400, G.ink2, 1.45f))
        Text(tr("op.door"), style = ui(13f, 700, G.ink2))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("op.width"), dw, { dw = it }, m, err(0), tried, modifier = Modifier.weight(1f))
            NumField(tr("op.height"), dh, { dh = it }, m, err(1), tried, modifier = Modifier.weight(1f))
        }
        Text(tr("op.window"), style = ui(13f, 700, G.ink2))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("op.width"), ww, { ww = it }, m, err(2), tried, modifier = Modifier.weight(1f))
            NumField(tr("op.height"), wh, { wh = it }, m, err(3), tried, modifier = Modifier.weight(1f))
        }
        NumField(tr("op.sill"), ws, { ws = it }, m, err(4), tried)
    }
}
