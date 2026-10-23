package uz.metrx.app.ui.projects

import androidx.activity.compose.BackHandler
import uz.metrx.app.ui.components.switchState
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Check
import uz.metrx.app.data.Item
import uz.metrx.app.data.Project
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.fmtDate
import uz.metrx.app.data.itemName
import uz.metrx.app.data.uid
import uz.metrx.app.data.wsIcon
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BackLink
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.CountPill
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

private val KIND_IC = mapOf("room" to "room", "drawing" to "pen", "photo" to "camera", "note" to "note")

/** A workspace: its rooms, then drawings, photos and notes, as cards (prototype PAGES.space). */
@Composable
fun SpaceScreen(r: Route.Space) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(r.pid) ?: return
    val w = p.floors.firstOrNull { it.id == r.wid } ?: return
    val items = w.items.sortedByDescending { it.created }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar {
                BackLink(dn(p.name, lang), { app.pop() }, Modifier.weight(1f, fill = false))
                Spacer(Modifier.weight(1f))
                GlassIconButton("more", tr("common.menu"), { app.sheet = Sheet.SpaceMenu(p.id, w.id) })
            }
            Row(Modifier.padding(start = 36.dp, end = 36.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon(wsIcon(w.type), G.cobalt, 22.dp, 2f) }
                Column {
                    Text(floorName(w, lang), style = ui(24f, 700, G.ink, 1.15f, -.01f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val typeName = tr("ws.t.${w.type}")
                    Text(if (floorName(w, lang) == typeName) tr("ws.one") else typeName, style = ui(13f, 400, G.ink2))
                }
            }
            val wsRooms = p.rooms.filter { it.floorId == w.id }
            if (wsRooms.isNotEmpty()) WsNums(wsRooms)
            val furn = p.furniture.filter { it.ws == w.id }.sortedByDescending { it.created }
            if (items.isEmpty() && wsRooms.isEmpty() && furn.isEmpty()) {
                Column(Modifier.weight(1f).fillMaxWidth().padding(start = 32.dp, end = 32.dp, top = 64.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    BlankSheet()
                    Spacer(Modifier.height(6.dp))
                    Text(tr("ws.blankT"), style = ui(18f, 600, G.ink, 1.4f), textAlign = TextAlign.Center)
                    Text(tr("ws.blankB"), style = ui(14.5f, 400, G.ink2, 1.4f), textAlign = TextAlign.Center)
                }
            } else {
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 104.dp).navigationBarsPadding(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    val rooms = p.rooms.filter { it.floorId == w.id }.sortedByDescending { it.created }
                    if (rooms.isNotEmpty()) Section(tr("ws.secRooms"), rooms.size) {
                        // the dashed add tile closes the rooms grid when there is nothing else
                        val cells: List<uz.metrx.app.data.Room?> = rooms + (if (items.isEmpty()) listOf(null) else emptyList())
                        cells.chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                row.forEach { rm -> if (rm != null) RoomCard(p, rm, lang, Modifier.weight(1f)) else AddTile(Modifier.weight(1f)) { app.sheet = Sheet.AddItem(p.id, w.id) } }
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                    // furniture orders: the kitchens and wardrobes designed here
                    if (furn.isNotEmpty()) Section(tr("kt.sec"), furn.size) {
                        furn.chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                row.forEach { f -> uz.metrx.app.ui.furniture.FurnitureCard(p, f, Modifier.weight(1f)) }
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                    if (items.isNotEmpty()) Section(tr("ws.secOther"), items.size) {
                        // two cards a row; the dashed "Qo‘shish" tile comes last (null)
                        (items + listOf<Item?>(null)).chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                row.forEach { cell -> if (cell != null) ItemCard(p, w, cell, lang, Modifier.weight(1f)) else AddTile(Modifier.weight(1f)) { app.sheet = Sheet.AddItem(p.id, w.id) } }
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }
        if (items.isEmpty() && p.rooms.none { it.floorId == w.id } && app.sheet == null) {
            // the dashed arrow from the empty state to the add button
            Canvas(Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 54.dp).offset(x = (-3).dp).size(96.dp, 80.dp)) {
                val k = size.width / 96f
                scale(k, k, pivot = Offset.Zero) {
                    drawPath(PathParser().parsePathString("M6 6C20 50 46 66 82 70").toPath(), Color.White.copy(alpha = .8f),
                        style = Stroke(2.5f, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))))
                    drawPath(PathParser().parsePathString("M72 60l12 10-14 6").toPath(), Color.White.copy(alpha = .8f), style = Stroke(2.5f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                }
            }
            val shape = RoundedCornerShape(27.dp)
            Row(
                Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(end = 15.dp, bottom = 16.dp).height(54.dp)
                    .dropShadow(shape, Shadow(20.dp, Color(0x591C4BD1), offset = DpOffset(0.dp, 8.dp)))
                    .clip(shape).background(G.cobalt).pressable({ app.sheet = Sheet.AddItem(p.id, w.id) }, .96f).padding(start = 16.dp, end = 20.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) { MIcon("plus", Color.White, 22.dp, 2.4f); Text(tr("ws.add"), style = ui(15f, 600, Color.White)) }
        }
    }
}

@Composable
private fun Section(title: String, n: Int, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.padding(horizontal = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = ui(15.5f, 600)); CountPill(n)
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { content() }
    }
}

/** The workspace's own totals: net wall, floor, measurements confirmed ("+?" while some rooms lack values). */
@Composable
private fun WsNums(rooms: List<uz.metrx.app.data.Room>) {
    val app = LocalApp.current
    val en = app.settings.lang == uz.metrx.app.core.Lang.EN
    var net = 0L; var nn = 0; var fl = 0L; var fn = 0; var need = 0; var conf = 0
    rooms.forEach { r ->
        uz.metrx.app.geo.areas(r, app.settings.angleSnap)?.let { a -> fl += a.floor; fn++; if (a.net != null) { net += a.net; nn++ } }
        val ks = uz.metrx.app.geo.stepKeys(r, app.settings.angleSnap); need += ks.size; conf += ks.count { r.dim(it).status == "conf" }
    }
    fun v(sum: Long, n: Int) = if (n > 0) uz.metrx.app.geo.fmtArea(sum, en) + (if (n < rooms.size) " +?" else "") else "?"
    Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NumTile(tr("pl.wall"), v(net, nn), tr("u.m2"), Modifier.weight(1f))
        NumTile(tr("ws.floor"), v(fl, fn), tr("u.m2"), Modifier.weight(1f))
        NumTile(tr("pl.meas"), if (need > 0) "$conf/$need" else "—", null, Modifier.weight(1f))
    }
}

@Composable
private fun NumTile(label: String, value: String, unit: String?, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(18.dp)).background(G.glass(.45f)).border(1.dp, G.rim, RoundedCornerShape(18.dp)).padding(start = 12.dp, end = 8.dp, top = 9.dp, bottom = 9.dp)) {
        Text(label, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, style = uz.metrx.app.ui.theme.num(17f, 800), maxLines = 1)
            if (unit != null && value != "?" && value != "—") Text(" $unit", style = ui(11f, 600, G.ink2), modifier = Modifier.padding(bottom = 2.dp))
        }
    }
}

/** A room plan card: a small plan with its sizes, the kind, the name and the next step or the net wall area. */
@Composable
private fun RoomCard(p: Project, r: uz.metrx.app.data.Room, lang: Lang, modifier: Modifier) {
    val app = LocalApp.current
    val shape = RoundedCornerShape(16.dp)
    val nx = app.ops.next(r)
    val c = when (nx.cls) { "ok" -> if (Theme.dark) G.green else Color(0xFF15803D); "recv" -> G.amberInk; "bad" -> G.err; else -> G.ink2 }
    Box(modifier.height(cardHeight()).glassCard(shape, shadowRadius = 24.dp, shadowY = 10.dp, shadowAlpha = .1f)) {
        Column(Modifier.fillMaxSize().clickable { app.push(Route.Editor(p.id, r.id)) }) {
            Box(Modifier.fillMaxWidth().height(129.dp).background(Color.White)) {
                uz.metrx.app.ui.editor.RoomThumb(r, dn(r.name, lang), app.settings.unit, lang == uz.metrx.app.core.Lang.EN, app.settings.angleSnap, true, Modifier.fillMaxSize().padding(top = 8.dp))
            }
            Column(Modifier.fillMaxWidth().padding(start = 10.dp, end = 42.dp, top = 8.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    MIcon("room", G.ink3, 15.dp, 2f); Text(tr("it.k.room"), style = ui(12f, 400, G.ink3), maxLines = 1)
                }
                Text(dn(r.name, lang), style = ui(14.5f, 600, G.ink, 1.25f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    MIcon(nx.icon, c, 13.dp, 2.2f); Text(nx.text, style = ui(12.5f, 400, c), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
        Box(Modifier.align(Alignment.BottomEnd).padding(bottom = 4.dp).size(44.dp).clip(CircleShape).clickable(role = Role.Button) { app.sheet = Sheet.RoomMenu(p.id, r.id) },
            contentAlignment = Alignment.Center) { MIcon("more", G.ink, 18.dp, 2f) }
        if (p.reportRooms[r.id] != false) Text("PDF", style = uz.metrx.app.ui.theme.num(10.5f, 600, Color.White, .06f),
            modifier = Modifier.padding(8.dp).clip(RoundedCornerShape(6.dp)).background(Color(0xCC0E1C36)).padding(horizontal = 6.dp, vertical = 4.dp))
    }
}

/** The dashed sheet of paper on an empty workspace (88 × 104). */
@Composable
private fun BlankSheet() {
    Canvas(Modifier.size(88.dp, 104.dp)) {
        val k = size.width / 88f
        scale(k, k, pivot = Offset.Zero) {
            val body = PathParser().parsePathString("M8 6h52l20 20v72H8z").toPath()
            drawPath(body, G.solid)
            val dash = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))
            drawPath(body, Color(0xFFC3CEDF), style = Stroke(2f, pathEffect = dash))
            drawPath(PathParser().parsePathString("M60 6v20h20").toPath(), Color(0xFFC3CEDF), style = Stroke(2f, pathEffect = dash))
        }
    }
}

/** A card for a drawing, a photo (its picture with the marks) or a note (its text and checklist). */
@Composable
private fun ItemCard(p: Project, w: Workspace, it: Item, lang: Lang, modifier: Modifier) {
    val app = LocalApp.current
    val shape = RoundedCornerShape(16.dp)
    Box(modifier.height(cardHeight()).glassCard(shape, shadowRadius = 24.dp, shadowY = 10.dp, shadowAlpha = .1f)) {
        Column(Modifier.fillMaxSize().clickable { if (it.kind == "note") app.push(Route.Note(p.id, w.id, it.id)) else app.push(Route.Markup(p.id, it.id)) }) {
            if (it.kind != "note") uz.metrx.app.ui.markup.MarkThumb(it, Modifier.fillMaxWidth().height(129.dp).background(if (it.kind == "photo") Color(0xFF0E1C36) else Color.White))
            else Column(
                Modifier.fillMaxWidth().height(129.dp).background(G.noteWash).padding(start = 12.dp, end = 12.dp, top = 32.dp, bottom = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (it.kind == "note") {
                    if (it.text.isNotBlank()) Text(dn(it.text, lang), style = ui(12.5f, 400, G.ink2, 1.35f), maxLines = 4, overflow = TextOverflow.Ellipsis)
                    if (it.checks.isNotEmpty()) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        MIcon("boxok", G.cobalt, 15.dp, 2f)
                        Text(tr("it.items", "d" to it.checks.count { c -> c.done }, "n" to it.checks.size), style = ui(12.5f, 600, G.cobalt))
                    }
                }
            }
            Column(Modifier.fillMaxWidth().padding(start = 10.dp, end = 42.dp, top = 8.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    MIcon(KIND_IC[it.kind] ?: "note", G.ink3, 15.dp, 2f)
                    Text(tr("it.k.${it.kind}"), style = ui(12f, 400, G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Text(itemName(it, lang), style = ui(14.5f, 600, G.ink, 1.25f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(fmtDate(if (it.edited > 0) it.edited else it.created), style = ui(12.5f, 400, G.ink2))
            }
        }
        Box(Modifier.align(Alignment.BottomEnd).padding(bottom = 4.dp).size(44.dp).clip(CircleShape).clickable(role = Role.Button) { app.sheet = Sheet.ItemMenu(p.id, w.id, it.id) },
            contentAlignment = Alignment.Center) { MIcon("more", G.ink, 18.dp, 2f) }
        if (it.inReport) Text("PDF", style = uz.metrx.app.ui.theme.num(10.5f, 600, Color.White, .06f),
            modifier = Modifier.padding(8.dp).clip(RoundedCornerShape(6.dp)).background(Color(0xCC0E1C36)).padding(horizontal = 6.dp, vertical = 4.dp))
    }
}

/**
 * Rooms, items and furniture cards: a 129 dp picture over three lines of text. The text part grows with the phone's
 * font size, so a large system font (MIUI's 115 %) does not squeeze the last line and cut off its commas.
 */
@Composable
internal fun cardHeight(): androidx.compose.ui.unit.Dp = 129.dp + 76.dp * maxOf(1f, androidx.compose.ui.platform.LocalDensity.current.fontScale)

@Composable
private fun AddTile(modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.height(cardHeight()).dashedGlass(24.dp).pressable(onClick, .98f),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically)
    ) {
        Box(Modifier.size(52.dp).dropShadow(CircleShape, Shadow(22.dp, G.cobalt.copy(alpha = .35f), offset = DpOffset(0.dp, 10.dp))).clip(CircleShape).background(G.cobalt),
            contentAlignment = Alignment.Center) { MIcon("plus", Color.White, 24.dp, 2.4f) }
        Text(tr("gl.add"), style = ui(15f, 700, G.cobalt2))
    }
}

/* ---------------- Note: a title, text and a checklist (prototype PAGES.note) ---------------- */

@Composable
fun NoteScreen(r: Route.Note) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(r.pid) ?: return
    val w = p.floors.firstOrNull { it.id == r.wid } ?: return
    val it = w.items.firstOrNull { x -> x.id == r.iid } ?: return
    val focus = LocalFocusManager.current
    // the text is edited locally and written to the project as it changes (the store coalesces the saves)
    var title by remember(it.id) { mutableStateOf(dn(it.name, lang)) }
    var text by remember(it.id) { mutableStateOf(dn(it.text, lang)) }
    val newCheck = remember { mutableStateOf<String?>(null) }
    val titleF = remember { FocusRequester() }
    // a fresh note starts with the cursor in its title
    LaunchedEffect(it.id) { if (it.name.isEmpty() && it.text.isEmpty() && it.checks.isEmpty()) runCatching { titleF.requestFocus() } }
    fun change(f: (Item) -> Item) = app.store.update(p.id) { pr ->
        pr.copy(floors = pr.floors.map { ws -> if (ws.id != w.id) ws else ws.copy(items = ws.items.map { x -> if (x.id == it.id) f(x).copy(edited = System.currentTimeMillis()) else x }) })
    }
    val done = it.checks.count { c -> c.done }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar {
                GlassIconButton("back", tr("nt.back"), { focus.clearFocus(); app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("it.k.note"), sub = floorName(w, lang))
                GlassIconButton("more", tr("common.menu"), { app.sheet = Sheet.ItemMenu(p.id, w.id, it.id) })
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 40.dp).navigationBarsPadding(),
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                GField(tr("nt.title"), title, { v -> title = v; change { x -> x.copy(name = v.trim()) } }, tr("nt.titlePh"), focusRequester = titleF)
                GField(tr("nt.text"), text, { v -> text = v; change { x -> x.copy(text = v) } }, tr("nt.textPh"), minLines = 4)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row { Text(tr("nt.list"), style = ui(15f, 700), modifier = Modifier.weight(1f)); if (it.checks.isNotEmpty()) Text(tr("it.items", "d" to done, "n" to it.checks.size), style = ui(13f, 500, G.ink3)) }
                    it.checks.forEach { c -> CheckRow(c, newCheck.value == c.id,
                        onToggle = { change { x -> x.copy(checks = x.checks.map { k -> if (k.id == c.id) k.copy(done = !k.done) else k }) } },
                        onText = { v -> change { x -> x.copy(checks = x.checks.map { k -> if (k.id == c.id) k.copy(text = v) else k }) } },
                        onDelete = { change { x -> x.copy(checks = x.checks.filter { k -> k.id != c.id }) } }) }
                    GBtn(tr("nt.add"), { val c = Check(uid()); newCheck.value = c.id; change { x -> x.copy(checks = x.checks + c) } }, Btn.SECONDARY, icon = "plus",
                        height = 44.dp, corner = 12.dp, fontSize = 14f, fill = false)
                }
                Row(
                    Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f))
                        .switchState(it.inReport).clickable(role = Role.Switch) { change { x -> x.copy(rep = !x.inReport) } }.padding(start = 12.dp, end = 4.dp, top = 8.dp, bottom = 8.dp).heightIn(min = 40.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(Modifier.size(36.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("doc", G.cobalt, 20.dp, 2f) }
                    Text(tr("it.report"), style = ui(15.5f, 500), modifier = Modifier.weight(1f))
                    Box(Modifier.padding(end = 8.dp)) { GSwitch(it.inReport) }
                }
            }
        }
    }
}

@Composable
private fun CheckRow(c: Check, focusNow: Boolean, onToggle: () -> Unit, onText: (String) -> Unit, onDelete: () -> Unit) {
    var v by remember(c.id) { mutableStateOf(c.text) }
    val fr = remember { FocusRequester() }
    LaunchedEffect(focusNow) { if (focusNow) runCatching { fr.requestFocus() } }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Checkbox, onClick = onToggle), contentAlignment = Alignment.Center) {
            MIcon(if (c.done) "boxok" else "box", G.cobalt, 22.dp, 2f)
        }
        Box(Modifier.weight(1f)) { GField(null, v, { v = it; onText(it) }, tr("nt.itemPh"), focusRequester = fr, imeAction = ImeAction.Done, done = c.done) }
        Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onDelete), contentAlignment = Alignment.Center) {
            MIcon("x", G.ink2, 20.dp, 2f)
        }
    }
}
