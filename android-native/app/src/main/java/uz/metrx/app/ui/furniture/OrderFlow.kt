package uz.metrx.app.ui.furniture

import uz.metrx.app.ui.rooms.RshSheetGo
import uz.metrx.app.ui.rooms.RshSheetSub
import uz.metrx.app.ui.rooms.RshTypeLabel
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Phone
import uz.metrx.app.core.shortMoney
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.fStage
import uz.metrx.app.data.floorName
import uz.metrx.app.data.installDate
import uz.metrx.app.data.newProject
import uz.metrx.app.data.uid
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.furniture.runMm
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.ui.loc.LocState
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.rooms.startRoomShape
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/*
 * The easier path for furniture makers (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html): a short
 * new-order form that names the order itself and goes straight into the room; the order's rooms with their furniture;
 * the install date worked out from the approval and the Narx tab's days, on the order and its card.
 */

/* ---------------- dates ---------------- */

/** "11-noy": the day and the month's short name in the app language. */
fun fmtDay(d: LocalDate, app: App): String = "${d.dayOfMonth}-" + app.t("fo.months").split(',').getOrElse(d.monthValue - 1) { d.monthValue.toString() }

/** The order's install date as a chip: grey, amber from 3 days before, red when late (until it is installed). */
@Composable
fun InstallChip(p: Project) {
    val app = LocalApp.current
    if (!app.settings.advanced) return   // no install dates in the simple app
    val d = installDate(p)
    if (d == null) { Text(tr("fo.noDate"), style = ui(12.5f, 600, G.ink3), maxLines = 1); return }
    val left = ChronoUnit.DAYS.between(LocalDate.now(), d).toInt()
    val open = fStage(p) < 5
    val late = open && left < 0; val soon = open && !late && left <= 3
    val tail = when { late -> " · " + tr("fo.lateV", "n" to -left); soon -> " · " + (if (left == 0) tr("fo.todayV") else tr("fo.soonV", "n" to left)); else -> "" }
    val (bg, fg) = when { late -> G.errWash to G.err; soon -> G.amberWash to G.amberInk; else -> G.ink.copy(alpha = .06f) to G.ink2 }
    Row(Modifier.clip(RoundedCornerShape(9.dp)).background(bg).padding(horizontal = 9.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        MIcon("calendar", fg, 14.dp, 2.2f)
        Text(tr("fo.installV", "d" to fmtDay(d, app)) + tail, style = ui(12.5f, 700, fg), maxLines = 1)
    }
}

/** The green round call button of an order (nothing when it has no phone). */
@Composable
fun CallButton(p: Project, modifier: Modifier = Modifier) {
    if (p.phone.isEmpty()) return
    val context = LocalContext.current
    Box(modifier.size(46.dp).clip(CircleShape).background(G.greenWash).clickable(role = Role.Button, onClickLabel = tr("pl.call")) {
        runCatching { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:+998" + Phone.digits(p.phone)))) }
    }, contentAlignment = Alignment.Center) { MIcon("phone", if (Theme.dark) G.green else Color(0xFF15803D), 20.dp, 2.2f) }
}

/** Under the order's name: the customer, or (when the name already says who) the address or phone. */
fun orderSub(p: Project, lang: Lang, sep: String): String {
    val who = dn(p.customer, lang); val addr = dn(p.address, lang)
    return if (who.isNotBlank() && dn(p.name, lang).endsWith(who)) addr.ifBlank { if (p.phone.isNotEmpty()) Phone.format(p.phone) else "" }
    else listOf(who, addr).filter { it.isNotBlank() }.joinToString(sep)
}

/* ---------------- rooms made behind the scenes ---------------- */

/** The room kinds a furniture maker adds (string keys fr.*); the first two decide kitchen or wardrobe. */
val F_ROOMS = listOf("kitchen", "bedroom", "living", "kids", "hall", "bath", "other")

/** What furniture a room is for: the kitchen room gets a kitchen, the others a wardrobe. */
fun roomKind(w: Workspace?): String = if (w?.type == "kitchen") "kitchen" else "wardrobe"

/** A workspace with a rectangular room in it, named [name]; returns the room's id. */
fun App.addFurnRoom(pid: String, type: String, name: String): String {
    val now = System.currentTimeMillis()
    val w = Workspace(uid(), name, type = if (type == "kitchen") "kitchen" else "room", created = now)
    val r = Room(uid(), w.id, name, created = now)
    store.update(pid) { it.copy(floors = it.floors + w, rooms = it.rooms + r) }
    return r.id
}

/** Opens a room in the editor with wall A waiting for the laser or typing. */
fun App.openRoom(pid: String, rid: String) { push(Route.Editor(pid, rid)); ops.focus(rid, "A") }

/** Draws the first room of a workspace that has none yet: its shape, sizes, height and openings (room-shape flow). */
fun App.drawRoomIn(pid: String, w: Workspace, lang: Lang) {
    store.get(pid)?.rooms?.firstOrNull { it.floorId == w.id }?.let { openRoom(pid, it.id); return }
    startRoomShape(pid, "into", w.type, floorName(w, lang), wid = w.id)
}

/* ---------------- New order ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun NewOrderScreen(industry: String = "furniture") {
    val app = LocalApp.current
    val lang = LocalLang.current
    var who by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var address by rememberSaveable { mutableStateOf("") }
    var tried by rememberSaveable { mutableStateOf(false) }
    // the "Joylashuv" block (room-shapes spec §1): GPS only, read when tapped; optional, like the address. It listens
    // quietly while the form is open (permission already given), so the tap is instant; nothing is kept until then
    var locState by remember { mutableStateOf(LocState.NONE) }
    var loc by remember { mutableStateOf<uz.metrx.app.data.Location?>(null) }
    var keptFails by remember { mutableStateOf(0) }
    val gps = uz.metrx.app.ui.loc.rememberGps(warm = true) { l ->
        if (locState != LocState.LOCATING) return@rememberGps
        if (l != null) { loc = l; locState = LocState.OK; app.haptic(uz.metrx.app.ui.ux.Hap.CONFIRM) }
        // a new search failed (location switched off…): the fix already on the form stays until it is removed
        else if (loc != null) { locState = LocState.OK; keptFails++ }
        else { locState = LocState.FAIL; app.haptic(uz.metrx.app.ui.ux.Hap.WARN) }
    }
    val ctx = androidx.compose.ui.platform.LocalContext.current
    LaunchedEffect(keptFails) {
        if (keptFails == 0) return@LaunchedEffect
        if (gps.off) app.say("loc.offT", kind = uz.metrx.app.ui.components.ToastKind.ERROR, action = "loc.settings") { uz.metrx.app.ui.loc.openLocationSettings(ctx) }
        else app.say("loc.fail", kind = uz.metrx.app.ui.components.ToastKind.ERROR)
    }
    val focus = LocalFocusManager.current
    val fWho = remember { FocusRequester() }; val fPhone = remember { FocusRequester() }; val fAddr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fWho.requestFocus() } }
    val whoErr = when { who.isBlank() -> tr("np.customerReq"); who.trim().length < 2 -> tr("np.customerShort"); else -> null }
    val phErr = Phone.errorKey(phone, false)?.let { tr(it) }
    val ok = whoErr == null && phErr == null

    fun create() {
        tried = true
        if (!ok || !app.once()) return
        focus.clearFocus()
        gps.cancel()
        // named after the customer; "Oshxona — Akmal" once they say what they need (renameOrder)
        val name = who.trim()
        val p = newProject(name, name, Phone.digits(phone), address.trim(), if (locState == LocState.OK) loc else null, app.settings.currency, app.settings.reportLang.code).copy(industry = industry, autoName = industry == "furniture")
        app.store.add(p)
        app.replaceTop(Route.Project(p.id))
        // room editor v2: "Nimadan boshlaymiz?" — the room first, or the trade's room-less way (rooms/StartSheet.kt)
        app.sheet = Sheet.StartOrder(p.id)
        app.say("np.created", "n" to name)
    }

    val imeOn = WindowInsets.isImeVisible
    val footer: @Composable (Modifier) -> Unit = { m -> FloatingFooter(m) { GBtn(tr("fo.create"), ::create, enabled = !tried || ok) } }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("x", tr("common.close"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("fo.new"))
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = if (imeOn) 16.dp else 120.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                GField(tr("fo.client"), who, { who = it }, tr("smp.customer"), error = whoErr, showError = tried, onIme = { fPhone.requestFocus() },
                    focusRequester = fWho, capitalization = KeyboardCapitalization.Words)
                GField(tr("fo.phone"), phone, { phone = it }, "90 123 45 67", optional = true, phone = true, error = phErr, showError = tried || phone.length >= 9,
                    onIme = { fAddr.requestFocus() }, focusRequester = fPhone)
                GField(tr("np.address"), address, { address = it }, tr("smp.address"), optional = true, imeAction = ImeAction.Done, onIme = { focus.clearFocus() }, focusRequester = fAddr)
                uz.metrx.app.ui.loc.LocFormBlock(locState, loc, gps, { locState = it }, { loc = it })
                Text(tr("fz.nextNote"), style = ui(13.5f, 400, G.ink2, 1.4f))
            }
            if (imeOn) footer(Modifier)
        }
        if (!imeOn) footer(Modifier.align(Alignment.BottomCenter))
    }
}

/* ---------------- the order's rooms with their furniture ---------------- */

@Composable
fun FRoomsTab(p: Project, lang: Lang, route: Route.Project, addCard: Boolean = true) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    val priced = remember(p.furniture, p.fprice, s.workshop, s.mats, s.hws) { priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, s.workshop, s.mats, s.hws) }
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        FreeCard(p, lang)
        if (p.floors.isEmpty() && p.furniture.none { it.roomId == null }) Text(tr("fz.empty"), style = ui(14.5f, 400, G.ink2), textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
        p.floors.forEach { w ->
            val room = p.rooms.firstOrNull { it.floorId == w.id }
            val drawn = room != null && stepKeys(room, s.angleSnap).all { room.dim(it).status == "conf" }
            val furn = p.furniture.filter { it.ws == w.id || (room != null && it.roomId == room.id) }
            val kind = roomKind(w)
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { if (room != null) app.openRoom(p.id, room.id) else app.push(Route.Space(p.id, w.id)) },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = if (Theme.dark) .1f else .8f)), contentAlignment = Alignment.Center) {
                        if (room != null) uz.metrx.app.editorThumb(room, Modifier.fillMaxSize().padding(4.dp)) else MIcon(if (kind == "kitchen") "kitchen" else "room", G.cobalt, 24.dp, 2f)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(floorName(w, lang), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val sz = room?.let { uz.metrx.app.geo.roomSize(it, s.angleSnap) }; val a = sz?.first; val b = sz?.second; val h = room?.dim("H")?.v
                        Text(if (drawn && a != null && b != null) uz.metrx.app.geo.fmtLen(a, s.furnUnit, en) + " × " + uz.metrx.app.geo.fmtLen(b, s.furnUnit, en) + " " + unitWord(s.furnUnit) +
                                (h?.let { " · h " + uz.metrx.app.geo.fmtLen(it, s.furnUnit, en) } ?: "")
                            else tr(if (room != null) "fo.notMeasured" else "fo.notDrawn"), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                furn.forEach { f ->
                    val ward = f.kind == "wardrobe"
                    val sub = if (ward && (uz.metrx.app.furniture.isItemPiece(f) || uz.metrx.app.furniture.boxes(f).size > 1)) freeSub(f, en)
                        else if (ward) uz.metrx.app.furniture.wardOfF(f)?.let { m -> uz.metrx.app.geo.fmtLen(m.w, s.furnUnit, en) + " × " +
                        uz.metrx.app.geo.fmtLen(uz.metrx.app.furniture.valsOf(f, s.workshop)["h"] ?: m.h, s.furnUnit, en) + " " + unitWord(s.furnUnit) } ?: ""
                        else tr("kt.l" + f.layout) + " · " + pogM(runMm(f), en) + " " + tr("kt.pm")
                    PieceRow(p, f, sub, priced.lines.firstOrNull { it.key == f.id }?.amount, lang, badge = if (!f.keep) null else ({
                        Text(tr("fz.big"), style = ui(11f, 700, G.err), maxLines = 1,
                            modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(G.errWash).padding(horizontal = 6.dp, vertical = 2.dp))
                    })) { app.kit.sel = null; app.push(if (ward) Route.Wardrobe(p.id, f.id) else Route.Kitchen(p.id, f.id)) }
                }
                when {
                    room == null -> TodoRow(tr("fo.drawRoom")) { app.drawRoomIn(p.id, w, lang) }
                    !drawn -> TodoRow(tr("ns.measureT")) { app.openRoom(p.id, room.id) }
                    furn.isEmpty() -> p.furniture.firstOrNull { it.roomId == null && it.kind == kind }?.let { loose ->
                        TodoRow(tr("fz.placeN", "n" to dn(loose.name, lang))) { app.push(Route.FPlace(p.id, loose.id, room.id)) }
                    } ?: TodoRow(tr(if (kind == "kitchen") "fo.addK" else "fo.addW")) { app.push(Route.FGallery(p.id, room.id)) }
                }
                // a measured kitchen without a kitchen yet: the auto kitchen, six styles built for this room
                if (drawn && room != null && kind == "kitchen" && furn.none { it.kind == "kitchen" })
                    TodoRow(tr("ak.entry")) { app.push(Route.AutoKitchen(p.id, room.id)) }
                val n = w.items.size
                if (n > 0 || room != null) Text(tr("fo.photos") + if (n > 0) " · $n" else "", style = ui(13f, 600, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.push(Route.Space(p.id, w.id)) }.padding(horizontal = 4.dp, vertical = 6.dp))
            }
        }
        // everything that is wrong with the order's pieces, in one place (bazis ideas, 23 Oct 2026), under them as in the mockup
        CheckCard(p)
        // the fronts' board and the handles of every piece in one tap
        SwapButton(p)
        if (p.rooms.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", modifier = Modifier.weight(1f), height = 48.dp, fontSize = 15f)
            GBtn(tr("pj.v3d"), { app.setTop(route.copy(view = "3d")) }, Btn.SECONDARY, icon = "cube", modifier = Modifier.weight(1f), height = 48.dp, fontSize = 15f)
        }
        // the client's 3D files of the room with the most furniture (a piece's own room: its menu)
        if (p.furniture.any { it.modules.isNotEmpty() }) GBtn(tr("sh3.btn"), { app.sheet = Sheet.Share3D(p.id) }, Btn.SECONDARY, icon = "share", height = 48.dp, fontSize = 15f)
        if (addCard) Row(
            Modifier.fillMaxWidth().height(60.dp).dashedGlass(22.dp).pressable({ app.push(Route.FGallery(p.id)) }, .98f),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
        ) {
            MIcon("plus", G.cobalt2, 22.dp, 2.2f)
            Text(tr("fz.addMore"), style = ui(16f, 700, G.cobalt2))
        }
    }
}

@Composable
private fun TodoRow(label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).dashedGlass(14.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MIcon("plus", G.cobalt2, 18.dp, 2.2f)
        Text(label, style = ui(14.5f, 700, G.cobalt2))
    }
}

/* ---------------- sheets: a new room, the install date ---------------- */

@Composable
fun OrderFlowSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.FNewRoom -> NewRoomSheet(s)
        is Sheet.FInstall -> InstallSheet(s.pid)
        is Sheet.LocAdd, is Sheet.Yol -> uz.metrx.app.ui.loc.LocSheet(s)
        else -> return false
    }
    return true
}

@Composable
private fun NewRoomSheet(s: Sheet.FNewRoom) {
    val app = LocalApp.current
    val pid = s.pid
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    fun nameFor(t: String): String = uz.metrx.app.data.nextName(p, "fr.$t", app.settings.lang)
    var type by rememberSaveable { mutableStateOf(when (s.kind) { "kitchen" -> "kitchen"; "wardrobe" -> "bedroom"; "other" -> "living"; else -> if (p.floors.none { it.type == "kitchen" }) "kitchen" else "bedroom" }) }
    var name by rememberSaveable { mutableStateOf(nameFor(type)) }
    fun create() {
        if (name.isBlank() || !app.once()) return
        // a suggested name is kept as its key, so it follows the language
        // the room's shape, sizes, height and openings come next (room-shape flow); the room is made at its end
        app.sheet = null
        app.startRoomShape(pid, "furniture", type, uz.metrx.app.data.suggestedName(name, "fr.$type", app.settings.lang), fid = s.fid)
    }
    GlassSheet(tr("fo.addRoom"), { app.sheet = null }, footer = { RshSheetGo(name.isNotBlank(), ::create) }) {
        RshSheetSub(p)
        RshTypeLabel()
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            F_ROOMS.forEach { t -> Chip(tr("fr.$t"), t == type) { type = t; name = nameFor(t) } }
        }
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr("fr.$type"), error = if (name.isBlank()) tr("nr.nameReq") else null, showError = true, imeAction = ImeAction.Done, onIme = ::create)
    }
}

@Composable
private fun InstallSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val zone = ZoneId.systemDefault()
    val auto = installDate(p.copy(install = 0))
    var day by remember { mutableStateOf(installDate(p) ?: LocalDate.now()) }
    fun save(v: LocalDate?) {
        app.store.update(pid) { it.copy(install = v?.atStartOfDay(zone)?.toInstant()?.toEpochMilli() ?: 0) }
        app.sheet = null; app.say("fo.dateSaved")
    }
    GlassSheet(tr("fo.dateT"), { app.sheet = null }, footer = { GBtn(tr("common.save"), { save(if (day == auto) null else day) }) }) {
        Text(tr("fo.dateB", "m" to p.fprice.days, "i" to p.fprice.inst), style = ui(13.5f, 400, G.ink2, 1.45f))
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn("−", { day = day.minusDays(1) }, Btn.SECONDARY, modifier = Modifier.size(56.dp), fontSize = 22f)
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(fmtDay(day, app), style = num(26f, 800))
                Text(day.year.toString(), style = ui(13f, 500, G.ink2))
            }
            GBtn("+", { day = day.plusDays(1) }, Btn.SECONDARY, modifier = Modifier.size(56.dp), fontSize = 22f)
        }
        if (auto != null && day != auto) Text(tr("fo.dateAuto") + " (" + fmtDay(auto, app) + ")", style = ui(14f, 700, G.cobalt2),
            modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { day = auto }.padding(vertical = 8.dp, horizontal = 4.dp))
    }
}

/* ---------------- the next step, under the order's header on every tab ---------------- */

/** What to do now with a furniture order, and the one button that does it (decided 20 Oct 2026). Nothing once paid. */
@Composable
fun NextStep(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val en = lang == Lang.EN
    val k = fStage(p)
    val m = uz.metrx.app.data.orderMoney(p)
    val mlnWord = tr("pl.mln")
    fun mln(v: java.math.BigInteger) = shortMoney(p, v, en, mlnWord).let { it.first + (it.second?.let { u -> " $u" } ?: "") }
    val rooms = p.floors.mapNotNull { w -> p.rooms.firstOrNull { it.floorId == w.id }?.let { w to it } }
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> stepKeys(r, s.angleSnap).any { r.dim(it).status != "conf" } }
    val bare = rooms.firstOrNull { (w, r) -> p.furniture.none { it.ws == w.id || it.roomId == r.id } }
    // a measured room with nothing in it and a room-less piece of its kind: the piece goes in
    val loose = bare?.let { (w, r) -> if (measuredRoom(r, s.angleSnap)) p.furniture.firstOrNull { it.roomId == null && it.kind == roomKind(w) } else null }
    // what they wanted that has neither a room nor a piece yet
    val pend = p.want?.firstOrNull { k -> p.furniture.none { uz.metrx.app.furniture.kindKey(it) == k } && (k == "other" || p.floors.none { roomKind(it) == k }) }
    val price = remember(p.furniture, p.fprice, s.workshop, s.mats, s.hws) { priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, s.workshop, s.mats, s.hws).price }
    // sending the design: with an error in the Check list, the list first
    val errs = remember(p.furniture, p.rooms, s.workshop, s.mats, s.angleSnap) { orderIssues(app, p).count { it.level == "err" } }
    fun send() = app.push(if (errs > 0) Route.FCheck(p.id) else Route.Report(p.id))
    data class Step(val title: String, val sub: String?, val button: String, val go: () -> Unit)
    val step: Step? = when {
        // the simple app has no stages: the steps of making the furniture, then sending the design
        !s.advanced && k >= 2 -> Step(tr("ns.shareT"), if (errs > 0) tr("bz.sendErr", "n" to errs) else tr("ns.shareS"), tr("ns.shareB")) { send() }
        k >= 6 -> null
        k == 5 -> m.left?.takeIf { it.signum() > 0 }?.let { Step(tr("ns.payT"), tr("fo.leftV", "v" to mln(it)), tr("fo.addPay")) { app.sheet = Sheet.FPay(p.id) } }
        k == 4 -> Step(tr("ns.installT"), installDate(p)?.let { tr("fo.installV", "d" to fmtDay(it, app)) }, tr("ns.installB")) {
            // installed today: the date becomes today's, so the card and the list say when it really happened
            val today = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            if (app.once()) { val q = app.store.update(p.id) { uz.metrx.app.data.nextStage(it).copy(install = today) }; if (q?.stage == "paid") app.say("fs.paid") } }
        k == 3 -> Step(tr("ns.makeT"), installDate(p)?.let { tr("fo.installV", "d" to fmtDay(it, app)) }, tr("ns.makeB")) { if (app.once()) app.store.update(p.id) { uz.metrx.app.data.nextStage(it) } }
        k == 2 -> Step(tr("ns.approveT"), p.quotes.lastOrNull()?.let { q -> tr("ns.approveS", "n" to q.no, "v" to mln(q.total.toBigIntegerOrNull() ?: java.math.BigInteger.ZERO)) }, tr("fo.approve")) { app.sheet = Sheet.FApprove(p.id) }
        p.want == null && p.floors.isEmpty() && p.furniture.isEmpty() -> Step(tr("ns.needT"), tr("ns.needS"), tr("ns.needB")) { app.push(Route.FGallery(p.id)) }
        undrawn != null -> Step(tr("ns.measureT"), floorName(undrawn, lang), tr("fo.drawRoom")) { app.drawRoomIn(p.id, undrawn, lang) }
        unmeasured != null -> Step(tr("ns.measureT"), tr("ns.measureS", "r" to floorName(unmeasured.first, lang)), tr("ns.measureB")) { app.openRoom(p.id, unmeasured.second.id) }
        loose != null && bare != null -> Step(tr("ns.placeT", "n" to dn(loose.name, lang), "r" to floorName(bare.first, lang)),
            tr("ns.placeS", "n" to dn(loose.name, lang), "r" to floorName(bare.first, lang)), tr("fz.toRoom")) { app.push(Route.FPlace(p.id, loose.id, bare.second.id)) }
        bare != null -> roomKind(bare.first).let { kind ->
            Step(tr(if (kind == "kitchen") "ns.designK" else "ns.designW"), tr("ns.designS", "r" to floorName(bare.first, lang)), tr(if (kind == "kitchen") "fo.addK" else "fo.addW")) {
                app.push(Route.FGallery(p.id, bare.second.id)) } }
        pend != null -> Step(tr(when (pend) { "kitchen" -> "ns.designK"; "other" -> "ns.designO"; else -> "ns.designW" }), tr("ns.pendS"), tr("ns.pendB")) { app.push(Route.FGallery(p.id)) }
        p.floors.isEmpty() && p.furniture.isEmpty() -> Step(tr("ns.needT"), tr("ns.needS"), tr("ns.needB")) { app.push(Route.FGallery(p.id)) }
        !s.advanced -> Step(tr("ns.shareT"), if (errs > 0) tr("bz.sendErr", "n" to errs) else tr("ns.shareS"), tr("ns.shareB")) { send() }
        else -> Step(tr("ns.quoteT"), if (price.signum() > 0) tr("ns.quoteS", "v" to mln(price)) else null, tr("ns.quoteB")) { app.sheet = Sheet.Issue(p.id) }
    }
    if (step == null) return
    Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(if (Theme.dark) G.blueWash else Color(0xFF0F1626))
        .padding(start = 16.dp, end = 10.dp, top = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("ns.label"), style = ui(11.5f, 600, Color.White.copy(alpha = .62f)))
            Text(step.title, style = ui(15.5f, 800, Color.White, 1.25f), maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (step.sub != null) Text(step.sub, style = ui(12.5f, 500, Color.White.copy(alpha = .75f)), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Text(step.button, style = ui(14f, 800, Color(0xFF0F1626)), maxLines = 2, textAlign = TextAlign.Center,
            modifier = Modifier.heightIn(min = 46.dp).widthIn(max = 150.dp).clip(RoundedCornerShape(15.dp)).background(Color.White)
                .clickable(role = Role.Button, onClick = step.go).padding(horizontal = 14.dp, vertical = 13.dp))
    }
}
