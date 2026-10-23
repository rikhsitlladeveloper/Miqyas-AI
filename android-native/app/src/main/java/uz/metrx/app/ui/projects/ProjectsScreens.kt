package uz.metrx.app.ui.projects

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import uz.metrx.app.core.Phone
import uz.metrx.app.data.Location
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.newProject
import uz.metrx.app.data.stats
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassHeader
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.main.NAV_SPACE
import uz.metrx.app.ui.main.PageTitle
import uz.metrx.app.ui.main.ProjectsEmpty
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/** A paid furniture order counts as done in the list's chips. */
private fun stageOf(p: Project) = if (p.isFurniture && p.stage == "paid") "done" else p.stage

/** Projects: search with a round +, three chips, compact rows (prototype glass PAGES.projects). */
@Composable
fun ProjectsList() {
    val app = LocalApp.current
    val lang = LocalLang.current
    val furniture = app.settings.furniture
    val tiler = app.settings.tiler
    val elec = app.settings.elec
    val plumb = app.settings.plumb
    val win = app.settings.win
    val all = app.store.projects
    // each industry sees its own projects (furniture orders, tilers' orders, the rest); the others stay one chip away (furniture plan section 3)
    fun mine(p: Project) = if (furniture) p.isFurniture else if (tiler) p.isTiler else if (elec) p.isElec else if (plumb) p.isPlumb else if (win) p.isWin else !p.isFurniture && !p.isTiler && !p.isElec && !p.isPlumb && !p.isWin
    val ps = all.filter { mine(it) }
    val others = all.filter { !mine(it) }
    // the simple furniture and tiler apps have no stages: no "in work / finished", just all of them (and the other industry's)
    val staged = !(furniture || tiler || elec || plumb || win) || app.settings.advanced
    // the filter lives with the app, so opening or deleting an order does not reset it
    val seg0 = app.ordersSeg
    val seg = if (seg0 == "other" && others.isEmpty()) (if (staged) "active" else "all") else if (!staged && seg0 != "other") "all" else seg0
    var q by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        GlassHeader({ app.sheet = Sheet.Device })
        PageTitle(tr(if (furniture || tiler || elec || plumb || win) "fo.tab" else "tab.projects"), Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 4.dp))
        if (all.isEmpty()) { ProjectsEmpty { app.push(Route.NewProject()) }; return@Column }
        val n = mapOf("active" to ps.count { stageOf(it) != "done" }, "done" to ps.count { stageOf(it) == "done" }, "all" to ps.size)
        val needle = q.trim().lowercase()
        val list = (if (seg == "other") others else ps).filter { p ->
            val inSeg = seg == "all" || seg == "other" || (if (seg == "done") stageOf(p) == "done" else stageOf(p) != "done")
            inSeg && (needle.isEmpty() || listOf(dn(p.name, lang), dn(p.customer, lang), dn(p.address, lang), p.phone).joinToString(" ").lowercase().contains(needle))
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 24.dp + NAV_SPACE).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                SearchBox(q, { q = it }, tr("gl.search"), Modifier.weight(1f))
                Box(
                    Modifier.size(52.dp).dropShadow(CircleShape, Shadow(22.dp, G.cobalt.copy(alpha = .38f), offset = DpOffset(0.dp, 10.dp)))
                        .clip(CircleShape).background(G.cobalt).topHighlight(.4f).pressable({ app.push(Route.NewProject()) }, .95f, label = tr(if (uz.metrx.app.ui.main.orderWords()) "fo.new" else "hm.t.new")),
                    contentAlignment = Alignment.Center
                ) { MIcon("plus", Color.White, 24.dp, 2.4f) }
            }
            // the chips share the width when they fit; a fourth one ("Other") scrolls into view rather than being cut off
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(end = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ((if (staged) listOf("active" to "pl.active", "done" to "pl.doneSeg") else emptyList()) + listOf("all" to "pl.allSeg") + (if (others.isNotEmpty()) listOf("other" to "fo.other") else emptyList())).forEach { (k, l) ->
                    val on = seg == k
                    Text("${tr(l)} · ${if (k == "other") others.size else n[k]}", style = ui(14f, if (on) 700 else 600, if (on) G.solid else G.slate),
                        maxLines = 1, softWrap = false,
                        modifier = Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(20.dp))
                            .background(if (on) G.ink else G.idle(.45f))
                            .border(1.dp, if (on) G.ink else G.idleRim, RoundedCornerShape(20.dp))
                            .clickable(role = Role.Tab) { app.ordersSeg = k }.padding(horizontal = 14.dp, vertical = 10.dp))
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // the simple app has no install dates: the newest first, as on Home
                (if ((furniture || tiler || elec || plumb || win) && seg != "other") (if (staged && furniture) uz.metrx.app.data.sortOrders(list) else list.sortedByDescending { it.created }) else list).forEach { p -> if (p.isFurniture) uz.metrx.app.ui.furniture.OrderRow(p) { app.push(Route.Project(p.id)) }
                    else if (p.isTiler && !staged) uz.metrx.app.ui.tiles.TOrderRow(p) { app.push(Route.Project(p.id)) }
                    else if (p.isElec && !staged) uz.metrx.app.ui.elec.EOrderRow(p) { app.push(Route.Project(p.id)) }
                    else if (p.isPlumb && !staged) uz.metrx.app.ui.plumb.POrderRow(p) { app.push(Route.Project(p.id)) }
                    else if (p.isWin && !staged) uz.metrx.app.ui.win.WOrderRow(p) { app.push(Route.Project(p.id)) } else ProjectRow(p) { app.push(Route.Project(p.id)) } }
                if (list.isEmpty()) Text(tr(if (uz.metrx.app.ui.main.orderWords()) (if (needle.isNotEmpty()) "fo.noMatch" else "fo.none") else if (needle.isNotEmpty()) "pl.noMatch" else "pl.none"), style = ui(14.5f, 400, G.ink2),
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}

@Composable
private fun SearchBox(value: String, onValue: (String) -> Unit, placeholder: String, modifier: Modifier) {
    val shape = RoundedCornerShape(26.dp)
    Row(
        modifier.height(52.dp).dropShadow(shape, Shadow(22.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, 8.dp)))
            .clip(shape).background(G.glass(.45f)).topHighlight().border(1.dp, G.rim, shape).padding(start = 16.dp, end = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        MIcon("search", G.ink2, 20.dp, 2.2f)
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = ui(16f, 400, Color(0xFF94A3B8)))
            BasicTextField(value, onValue, singleLine = true, textStyle = ui(16f), cursorBrush = SolidColor(G.cobalt),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search), modifier = Modifier.fillMaxWidth())
        }
        if (value.isNotEmpty()) MIcon("x", G.ink3, 18.dp, 2f, Modifier.clickable(role = Role.Button) { onValue("") })
    }
}

private val EMPTY_THUMB by lazy { PathParser().parsePathString("M5 6h22v12h8v16H5z M5 22h14 M19 22v12").toPath() }

/** One project row: a small plan, the name and stage, the customer and area, the measuring progress. */
@Composable
private fun ProjectRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    val st = stats(p, LocalApp.current.settings.angleSnap)
    val stage = stageOf(p)
    val (bg, fg) = when {
        p.rooms.isEmpty() -> G.ink.copy(alpha = .07f) to G.slate
        stage == "done" -> Color(0x2416A34A) to (if (Theme.dark) G.green else Color(0xFF15803D))
        stage == "measure" -> Color(0x24EA8C00) to (if (Theme.dark) G.amberInk else Color(0xFF9A5800))
        else -> G.cobalt.copy(alpha = .12f) to G.cobalt2
    }
    val label = if (p.rooms.isEmpty()) tr("gl.new") else tr("stage.$stage")
    val pct = if (st.need > 0) st.conf.toFloat() / st.need else 0f
    Row(
        Modifier.fillMaxWidth().glassCard(RoundedCornerShape(26.dp)).pressable(onClick).padding(start = 12.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(Modifier.size(64.dp).clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = .7f)).topHighlight(1f, 1.dp), contentAlignment = Alignment.Center) {
            val r0 = p.rooms.firstOrNull()
            if (r0 != null) uz.metrx.app.editorThumb(r0, Modifier.size(46.dp, 40.dp))
            else Canvas(Modifier.size(40.dp)) { val k = size.width / 40f; Theme.onPaper { scale(k, k, pivot = Offset.Zero) { drawPath(EMPTY_THUMB, G.cobalt, style = Stroke(1.8f)) } } }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(dn(p.name, lang), style = ui(16f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Text(label, style = ui(12f, 700, fg), maxLines = 1, modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(bg).padding(horizontal = 10.dp, vertical = 4.dp))
            }
            val area = if (st.nets > 0) uz.metrx.app.geo.fmtArea(st.net, lang == uz.metrx.app.core.Lang.EN) + " " + tr("u.m2") else "— " + tr("u.m2")
            Text(listOf(dn(p.customer, lang), area).filter { it.isNotBlank() }.joinToString(" · "), style = ui(13f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(3.dp)).background(G.ink.copy(alpha = .08f))) {
                    Box(Modifier.fillMaxWidth(pct).height(6.dp).clip(RoundedCornerShape(3.dp)).background(if (pct >= 1f) G.green else G.cobalt))
                }
                Text("${st.conf}/${st.need}", style = ui(12f, 700, G.slate))
            }
        }
    }
}

/* ---------------- New project and Edit project (prototype PAGES.newProject) ---------------- */

@Composable
fun NewProjectScreen(editId: String?) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val edit = editId?.let { app.store.get(it) }
    var name by rememberSaveable { mutableStateOf(edit?.let { dn(it.name, lang) } ?: "") }
    var customer by rememberSaveable { mutableStateOf(edit?.let { dn(it.customer, lang) } ?: "") }
    var phone by rememberSaveable { mutableStateOf(edit?.phone ?: "") }
    var address by rememberSaveable { mutableStateOf(edit?.let { dn(it.address, lang) } ?: "") }
    var loc by remember { mutableStateOf(edit?.location) }
    var locating by remember { mutableStateOf(false) }
    var tried by rememberSaveable { mutableStateOf(false) }
    val touched = remember { mutableStateOf(setOf<String>()) }
    val focus = LocalFocusManager.current
    val fName = remember { FocusRequester() }; val fCust = remember { FocusRequester() }; val fPhone = remember { FocusRequester() }; val fAddr = remember { FocusRequester() }
    // a new project opens with the cursor in its name, as in the prototype
    androidx.compose.runtime.LaunchedEffect(Unit) { if (edit == null) runCatching { fName.requestFocus() } }

    val nameErr = if (name.isBlank()) tr("np.nameReq") else null
    val custErr = if (customer.isBlank()) tr("np.customerReq") else null
    val phErr = Phone.errorKey(phone, false)?.let { tr(it) }
    val ok = nameErr == null && custErr == null && phErr == null
    fun show(k: String) = tried || k in touched.value
    fun touch(k: String) { touched.value = touched.value + k }

    val context = LocalContext.current
    val askLocation = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        if (res.values.any { it }) { locating = true; currentLocation(context) { l -> locating = false; if (l != null) loc = l else app.say("loc.fail", kind = ToastKind.ERROR) } }
        else app.say("loc.fail", kind = ToastKind.ERROR)
    }
    fun locate() {
        val has = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (has) { locating = true; currentLocation(context) { l -> locating = false; if (l != null) loc = l else app.say("loc.fail", kind = ToastKind.ERROR) } }
        else askLocation.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }

    fun save() {
        tried = true
        if (!ok) return
        focus.clearFocus()
        if (edit != null) {
            app.store.update(edit.id) { it.copy(name = keep(it.name, name.trim(), lang), autoName = it.autoName && keep(it.name, name.trim(), lang) == it.name, customer = keep(it.customer, customer.trim(), lang), phone = Phone.digits(phone), address = keep(it.address, address.trim(), lang), location = loc) }
            app.pop(); app.say("op.saved", "o" to name.trim())
        } else {
            val p = newProject(name.trim(), customer.trim(), Phone.digits(phone), address.trim(), loc, app.settings.currency, app.settings.reportLang.code)
                .let { if (app.settings.furniture) it.copy(industry = "furniture") else if (uz.metrx.app.trades.isTrade(app.settings.industry)) it.copy(industry = app.settings.industry!!) else it }
            app.store.add(p)
            app.replaceTop(Route.Project(p.id))
            app.say("np.created", "n" to name.trim())
        }
    }

    // with the keyboard up the button sits in the page under the form (not floating over it), so the field being typed
    // in scrolls above the button instead of hiding behind it
    @OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
    val imeOn = WindowInsets.isImeVisible
    val footer: @Composable (Modifier) -> Unit = { m ->
        FloatingFooter(m) { GBtn(tr(if (edit != null) "common.save" else if (app.settings.furniture) "fo.create" else "np.create"), ::save, enabled = ok) }
    }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton(if (edit != null) "back" else "x", tr(if (edit != null) "nt.back" else "common.close"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                val fu = if (edit != null) edit.industry != "build" else uz.metrx.app.ui.main.orderWords()
                BarTitle(tr(if (fu) "fo.details" else "np.editTitle"), eyebrow = if (edit == null) tr(if (fu) "fo.new" else "np.title") else null)
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = if (imeOn) 16.dp else 120.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                val furn = if (edit != null) edit.isFurniture else app.settings.furniture
                GField(tr(if (furn) "fo.name" else "np.name"), name, { name = it }, tr(if (furn) "fo.namePh" else "smp.project"), error = nameErr, showError = show("name"), onBlur = { touch("name") }, onIme = { fCust.requestFocus() }, focusRequester = fName,
                    capitalization = KeyboardCapitalization.Sentences)
                GField(tr("np.customerName"), customer, { customer = it }, tr("smp.customer"), error = custErr, showError = show("customer"), onBlur = { touch("customer") },
                    onIme = { fPhone.requestFocus() }, focusRequester = fCust, capitalization = KeyboardCapitalization.Words)
                GField(tr("np.customerPhone"), phone, { phone = it }, "90 123 45 67", optional = true, phone = true, error = phErr, showError = show("phone"),
                    onBlur = { touch("phone") }, onIme = { fAddr.requestFocus() }, focusRequester = fPhone)
                GField(tr("np.address"), address, { address = it }, tr("smp.address"), optional = true, imeAction = ImeAction.Done, onIme = { focus.clearFocus() }, focusRequester = fAddr)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row { Text(tr("np.location"), style = ui(15f, 700), modifier = Modifier.weight(1f)); Text(tr("common.optional").replaceFirstChar { it.uppercase() }, style = ui(13f, 500, G.ink3)) }
                    LocationBlock(loc, locating, ::locate) { loc = null }
                    Text(tr("loc.note"), style = ui(13f, 400, G.ink2))
                }
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(G.ink.copy(alpha = .06f)).padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top
                ) {
                    MIcon("sliders", G.ink2, 18.dp, 2f)
                    val cur = edit?.currency ?: app.settings.currency
                    val rl = edit?.reportLang?.let { uz.metrx.app.core.Lang.of(it) } ?: app.settings.reportLang
                    // the simple furniture app has no prices, so no currency either
                    Text(if (furn && !app.settings.advanced) tr("np.fromSettingsL", "l" to rl.longName) else tr("np.fromSettings", "c" to cur, "l" to rl.longName),
                        style = ui(13.5f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f))
                    if (edit == null) Text(tr("np.change"), style = ui(13.5f, 700, G.cobalt), modifier = Modifier.clickable(role = Role.Button) { app.sheet = Sheet.Currency }.padding(horizontal = 4.dp, vertical = 2.dp))
                }
            }
            if (imeOn) footer(Modifier)
        }
        if (!imeOn) footer(Modifier.align(Alignment.BottomCenter))
    }
}

/** A name that was a sample key stays a key when the text is unchanged. */
private fun keep(old: String, typed: String, lang: uz.metrx.app.core.Lang) = if (dn(old, lang) == typed) old else typed

@Composable
private fun LocationBlock(loc: Location?, locating: Boolean, onLocate: () -> Unit, onRemove: () -> Unit) {
    if (loc == null && !locating) { GBtn(tr("loc.get"), onLocate, Btn.SECONDARY, icon = "pin"); return }
    val shape = RoundedCornerShape(18.dp)
    Column(Modifier.fillMaxWidth().clip(shape).background(G.glass(.6f)).border(1.dp, G.rim, shape)) {
        // a small drawn map: a pale grid, the accuracy circle and the pin
        Box(Modifier.fillMaxWidth().height(96.dp).background(if (Theme.dark) G.blueWash else Color(0xFFE8EEF8)), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val step = 22.dp.toPx(); var x = 0f
                while (x < size.width) { drawLine(Color(0x1A3550E0), Offset(x, 0f), Offset(x, size.height), 1f); x += step }
                var y = 0f
                while (y < size.height) { drawLine(Color(0x1A3550E0), Offset(0f, y), Offset(size.width, y), 1f); y += step }
                drawCircle(G.cobalt.copy(alpha = .14f), 26.dp.toPx(), center)
            }
            if (!locating) MIcon("pin", G.cobalt, 28.dp, 2.2f)
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("pin", G.ink2, 18.dp, 2f)
            if (locating) Text(tr("loc.locating"), style = ui(14f, 500, G.ink2))
            else if (loc != null) {
                Text("%.5f, %.5f".format(java.util.Locale.ROOT, loc.lat, loc.lng), style = ui(14f, 700))
                Text(tr("loc.acc", "m" to loc.acc), style = ui(13f, 400, G.ink2))
            }
        }
        if (!locating && loc != null) Row(Modifier.fillMaxWidth().padding(start = 6.dp, end = 6.dp, bottom = 6.dp)) {
            Text(tr("loc.again"), style = ui(14f, 700, G.cobalt), modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onLocate).padding(horizontal = 8.dp, vertical = 12.dp))
            Text(tr("loc.remove"), style = ui(14f, 700, G.err), modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onRemove).padding(horizontal = 8.dp, vertical = 12.dp))
        }
    }
}

/** One GPS fix (GPS works without internet). Calls back with null when the phone can't get one within 15 s. */
@SuppressLint("MissingPermission")
private fun currentLocation(context: Context, done: (Location?) -> Unit) {
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    val provider = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).firstOrNull { runCatching { lm.isProviderEnabled(it) }.getOrDefault(false) }
    if (provider == null) { done(null); return }
    val main = android.os.Handler(android.os.Looper.getMainLooper())
    var finished = false
    fun finish(l: android.location.Location?) {
        if (finished) return; finished = true
        done(l?.let { Location(it.latitude, it.longitude, maxOf(1, it.accuracy.toInt()), System.currentTimeMillis()) })
    }
    main.postDelayed({ finish(lm.getLastKnownLocation(provider)) }, 15000)
    if (Build.VERSION.SDK_INT >= 30) {
        lm.getCurrentLocation(provider, CancellationSignal(), ContextCompat.getMainExecutor(context)) { finish(it) }
    } else {
        @Suppress("DEPRECATION")
        lm.requestSingleUpdate(provider, { l -> finish(l) }, android.os.Looper.getMainLooper())
    }
}
