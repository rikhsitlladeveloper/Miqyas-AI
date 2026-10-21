package uz.metrx.app.ui.projects

import uz.metrx.app.ui.furniture.outOfRooms
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Item
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.itemName
import uz.metrx.app.data.uid
import uz.metrx.app.data.WS_TYPES
import uz.metrx.app.data.wsCounts
import uz.metrx.app.data.wsIcon
import uz.metrx.app.data.wsStoreName
import uz.metrx.app.data.wsSuggest
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.ActionRow
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.ListBox
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/** The sheets of projects and workspaces. Returns false for sheets it doesn't own. */
@Composable
fun ProjectSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.ProjectMenu -> ProjectMenu(s)
        is Sheet.ProjectDelete -> ProjectDelete(s)
        is Sheet.NewSpace -> NewSpace(s)
        is Sheet.SpaceMenu -> SpaceMenu(s)
        is Sheet.SpaceDelete -> SpaceDelete(s)
        is Sheet.AddItem -> AddItem(s)
        is Sheet.ItemMenu -> ItemMenu(s)
        is Sheet.ItemRename -> ItemRename(s)
        is Sheet.ItemMove -> ItemMove(s)
        Sheet.Currency -> CurrencySheet()
        is Sheet.Row -> key(s) { RowSheet(s) }
        is Sheet.Areas -> AreasSheet(s)
        is Sheet.ReportSetup -> uz.metrx.app.ui.report.ReportSetupSheet(s)
        is Sheet.Issue -> key(s) { uz.metrx.app.ui.report.IssueSheet(s) }
        else -> return false
    }
    return true
}

private fun App.close() { sheet = null }

@Composable
private fun ProjectMenu(s: Sheet.ProjectMenu) {
    val app = LocalApp.current
    // a furniture maker's project is an order
    val fu = app.store.get(s.pid)?.isFurniture == true
    GlassSheet(tr(if (fu) "fo.details" else "pr.menuEdit"), { app.close() }) {
        ListBox {
            ActionRow("edit", tr(if (fu) "fo.details" else "pr.menuEdit"), { app.close(); app.push(Route.NewProject(s.pid)) })
            Hairline()
            ActionRow("trash", tr(if (fu) "fo.menuDelete" else "pr.menuDelete"), { app.sheet = Sheet.ProjectDelete(s.pid) }, danger = true)
        }
    }
}

@Composable
private fun ProjectDelete(s: Sheet.ProjectDelete) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    GlassSheet(tr("pj.delQ", "n" to dn(p.name, lang)), { app.close() }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.cancel"), { app.close() }, Btn.SECONDARY, modifier = Modifier.weight(1f))
            GBtn(tr("common.delete"), {
                val name = dn(p.name, lang)
                val (gone, idx) = app.store.delete(p.id) ?: return@GBtn
                app.close(); app.dropMissing()
                app.say("pr.deleted", "n" to name, action = "common.undo") { app.store.restore(gone, idx) }
            }, Btn.DANGER, icon = "trash", modifier = Modifier.weight(1f))
        }
    }) {
        val pre = if (p.isFurniture) "fo" else "pj"
        Text(if (p.quotes.isNotEmpty()) tr("$pre.delB", "q" to p.quotes.size) else tr("$pre.delB0"), style = ui(15f, 400, G.ink2, 1.45f))
    }
}

/** New workspace, or edit its name and type (prototype SHEETS.newSpace). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun NewSpace(s: Sheet.NewSpace) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val edit = s.editWid?.let { id -> p.floors.firstOrNull { it.id == id } }
    var type by rememberSaveable { mutableStateOf(edit?.type ?: "floor") }
    var name by rememberSaveable { mutableStateOf(edit?.let { floorName(it, lang) } ?: wsSuggest(p, "floor", lang)) }
    var tried by remember { mutableStateOf(false) }
    val err = if (name.isBlank()) tr("ws.nameReq") else null
    fun pick(k: String) {
        val cur = name.trim()
        // a suggested name follows the type; a typed name stays
        if (cur.isEmpty() || cur == wsSuggest(p, type, lang) || (edit != null && cur == floorName(edit, lang))) name = if (edit != null && k == edit.type) floorName(edit, lang) else wsSuggest(p, k, lang)
        type = k
    }
    fun save() {
        tried = true
        val nm = name.trim(); if (nm.isEmpty()) return
        if (edit != null) {
            app.store.update(p.id) { pr -> pr.copy(floors = pr.floors.map { if (it.id == edit.id) it.copy(name = wsStoreName(pr, nm, type, lang), type = type) else it }) }
            app.close(); app.say("op.saved", "o" to nm)
        } else {
            val w = Workspace(uid(), wsStoreName(p, nm, type, lang), type, emptyList(), System.currentTimeMillis())
            app.store.update(p.id) { it.copy(floors = it.floors + w) }
            app.close(); app.push(Route.Space(p.id, w.id)); app.say("ws.created", "n" to nm)
        }
    }
    GlassSheet(tr(if (edit != null) "ws.menuEdit" else "ws.new"), { app.close() }, footer = {
        GBtn(tr(if (edit != null) "common.save" else "ws.create"), ::save, enabled = err == null)
    }) {
        GField(tr("ws.name"), name, { name = it }, wsSuggest(p, type, lang), error = err, showError = tried, imeAction = ImeAction.Done, onIme = ::save)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("ws.type"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                WS_TYPES.forEach { (k, icon) ->
                    val on = type == k
                    Row(
                        Modifier.heightIn(min = 44.dp).clip(CircleShape).background(G.glass(.55f))
                            .border(if (on) 1.5.dp else 1.dp, if (on) G.cobalt else G.rim, CircleShape)
                            .clickable(role = Role.RadioButton) { pick(k) }.padding(start = 12.dp, end = 14.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        MIcon(icon, if (on) G.cobalt2 else G.ink, 18.dp, 2f)
                        Text(tr("ws.t.$k"), style = ui(15f, if (on) 600 else 500, if (on) G.cobalt2 else G.ink))
                    }
                }
            }
        }
    }
}

@Composable
private fun SpaceMenu(s: Sheet.SpaceMenu) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val w = app.store.get(s.pid)?.floors?.firstOrNull { it.id == s.wid } ?: run { app.close(); return }
    GlassSheet(floorName(w, lang), { app.close() }) {
        ListBox {
            ActionRow("edit", tr("ws.menuEdit"), { app.sheet = Sheet.NewSpace(s.pid, s.wid) })
            Hairline()
            ActionRow("trash", tr("ws.menuDel"), { app.sheet = Sheet.SpaceDelete(s.pid, s.wid) }, danger = true)
        }
    }
}

@Composable
private fun SpaceDelete(s: Sheet.SpaceDelete) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val w = p.floors.firstOrNull { it.id == s.wid } ?: run { app.close(); return }
    val counts = wsCounts(p, w, lang)
    GlassSheet(tr("ws.delQ", "n" to floorName(w, lang)), { app.close() }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.cancel"), { app.close() }, Btn.SECONDARY, modifier = Modifier.weight(1f))
            GBtn(tr("it.del"), {
                val name = floorName(w, lang)
                val idx = p.floors.indexOf(w)
                val rooms = p.rooms.filter { it.floorId == w.id }
                val ids = rooms.map { it.id }.toSet()
                val pieces = p.furniture.filter { it.roomId in ids }
                app.store.update(p.id) { pr -> pr.copy(floors = pr.floors.filter { it.id != w.id }, rooms = pr.rooms.filter { it.floorId != w.id }, furniture = app.outOfRooms(pr, ids)) }
                app.close(); app.dropMissing()
                app.say("ws.deleted", "n" to name, action = "common.undo") {
                    app.store.update(p.id) { pr -> pr.copy(floors = pr.floors.toMutableList().apply { add(idx.coerceIn(0, size), w) }, rooms = pr.rooms + rooms,
                        furniture = pr.furniture.map { f -> pieces.firstOrNull { it.id == f.id } ?: f }) }
                }
            }, Btn.DANGER, icon = "trash", modifier = Modifier.weight(1f))
        }
    }) {
        Text(if (counts.isNotEmpty()) tr("ws.delB", "c" to counts) else tr("ws.delBEmpty"), style = ui(15f, 400, G.ink2, 1.45f))
    }
}

/** "+": drawing, photo or note; a drawing then asks room plan or free drawing (prototype SHEETS.addItem). */
@Composable
private fun AddItem(s: Sheet.AddItem) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val w = p.floors.firstOrNull { it.id == s.wid } ?: run { app.close(); return }
    when (s.step) {
        "sketch", "photo" -> GlassSheet(tr("add.${s.step}"), { app.close() }, back = { app.sheet = s.copy(step = "root") }) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 6.dp)) {
                if (s.step == "sketch") {
                    BigRow("room", "add.plan", "add.planD") { app.sheet = Sheet.NewRoom(p.id, w.id) }
                    BigRow("pen", "add.free", "add.freeD") { app.mk.newDrawing(p.id, w.id) }
                } else {
                    BigRow("camera", "add.camera", "add.cameraD") { app.close(); app.mk.launch?.invoke(uz.metrx.app.ui.markup.PhotoTarget(p.id, w.id), true) }
                    BigRow("folder", "add.gallery", "add.galleryD") { app.close(); app.mk.launch?.invoke(uz.metrx.app.ui.markup.PhotoTarget(p.id, w.id), false) }
                }
            }
        }
        else -> GlassSheet(tr("add.title", "n" to floorName(w, lang)), { app.close() }) {
            // furniture orders: the kitchen (or wardrobe) for the measured room comes first
            if (p.isFurniture) BigRow("kitchen", "kt.addRow", "kt.addRowD") {
                // the gallery, for the workspace's room when it is measured
                val rid = p.rooms.firstOrNull { it.floorId == w.id && uz.metrx.app.ui.furniture.measuredRoom(it, app.settings.angleSnap) }?.id
                app.close(); app.push(Route.FGallery(p.id, rid))
            }
            Row(Modifier.padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf("sketch" to "pen", "photo" to "camera", "note" to "note").forEach { (k, icon) ->
                    Column(
                        Modifier.weight(1f).heightIn(min = 150.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f))
                            .pressable({ if (k == "note") newNote(app, p.id, w.id) else app.sheet = s.copy(step = k) }, .97f)
                            .padding(start = 6.dp, end = 6.dp, top = 16.dp, bottom = 14.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(Modifier.size(56.dp).clip(RoundedCornerShape(16.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                            MIcon(icon, G.cobalt, 30.dp, 2f)
                        }
                        Text(tr("add.$k"), style = ui(15f, 600), textAlign = TextAlign.Center, modifier = Modifier.padding(top = 4.dp))
                        Text(tr("add.${k}D"), style = ui(12f, 400, G.ink2, 1.3f), textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
}

private fun newNote(app: App, pid: String, wid: String) {
    val now = System.currentTimeMillis()
    val item = Item(uid(), "note", created = now, edited = now, rep = false)
    app.store.update(pid) { pr -> pr.copy(floors = pr.floors.map { w -> if (w.id == wid) w.copy(items = w.items + item) else w }) }
    app.close()
    app.push(Route.Note(pid, wid, item.id))
}

@Composable
internal fun BigRow(icon: String, title: String, desc: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .06f)).pressable(onClick, .98f).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            MIcon(icon, G.cobalt, 22.dp, 2f)
        }
        Column(Modifier.weight(1f)) {
            Text(tr(title), style = ui(15.5f, 600))
            Text(tr(desc), style = ui(13f, 400, G.ink2, 1.35f))
        }
        MIcon("chev", G.ink, 18.dp, 2f)
    }
}

/* ---------------- one item: rename, move, duplicate, report, delete (prototype SHEETS.itemMenu) ---------------- */

private fun App.item(pid: String, wid: String, iid: String): Pair<Workspace, Item>? {
    val w = store.get(pid)?.floors?.firstOrNull { it.id == wid } ?: return null
    return w to (w.items.firstOrNull { it.id == iid } ?: return null)
}

private fun App.changeItem(pid: String, wid: String, iid: String, f: (Item) -> Item) {
    store.update(pid) { pr -> pr.copy(floors = pr.floors.map { w -> if (w.id != wid) w else w.copy(items = w.items.map { if (it.id == iid) f(it) else it }) }) }
}

@Composable
private fun ItemMenu(s: Sheet.ItemMenu) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val (w, it) = app.item(s.pid, s.wid, s.iid) ?: run { app.close(); return }
    GlassSheet(itemName(it, lang), { app.close() }) {
        ListBox {
            ActionRow("edit", tr("it.rename"), { app.sheet = Sheet.ItemRename(s.pid, s.wid, s.iid) })
            Hairline()
            ActionRow("layers", tr("it.move"), { app.sheet = Sheet.ItemMove(s.pid, s.wid, s.iid) })
            Hairline()
            ActionRow("copy", tr("it.dup"), {
                val now = System.currentTimeMillis()
                val copy = it.copy(id = uid(), name = app.t("it.copy", "n" to itemName(it, lang)), checks = it.checks.map { c -> c.copy(id = uid()) }, els = it.els.map { e -> e.copy(id = uid()) }, created = now, edited = now)
                app.store.update(s.pid) { pr -> pr.copy(floors = pr.floors.map { x -> if (x.id == w.id) x.copy(items = x.items + copy) else x }) }
                app.close(); app.say("op.added", "o" to itemName(copy, lang))
            })
            Hairline()
            ActionRow("doc", tr("it.report"), { app.changeItem(s.pid, s.wid, s.iid) { x -> x.copy(rep = !x.inReport) } }, trailing = { GSwitch(it.inReport) })
            Hairline()
            ActionRow("trash", tr("it.del"), {
                val name = itemName(it, lang)
                val idx = w.items.indexOf(it)
                app.store.update(s.pid) { pr -> pr.copy(floors = pr.floors.map { x -> if (x.id == w.id) x.copy(items = x.items.filter { y -> y.id != it.id }) else x }) }
                app.close(); app.dropMissing()
                app.say("it.deleted", "n" to name, action = "common.undo") {
                    app.store.update(s.pid) { pr -> pr.copy(floors = pr.floors.map { x -> if (x.id == w.id) x.copy(items = x.items.toMutableList().apply { add(idx.coerceIn(0, size), it) }) else x }) }
                }
            }, danger = true)
        }
    }
}

@Composable
private fun ItemRename(s: Sheet.ItemRename) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val (_, it) = app.item(s.pid, s.wid, s.iid) ?: run { app.close(); return }
    var v by rememberSaveable { mutableStateOf(dn(it.name, lang)) }
    val err = if (v.isBlank() && it.kind != "note") tr("ws.nameReq") else null
    val fr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    fun save() { if (err != null) return; app.changeItem(s.pid, s.wid, s.iid) { x -> x.copy(name = if (dn(x.name, lang) == v.trim()) x.name else v.trim(), edited = System.currentTimeMillis()) }; app.close() }
    GlassSheet(tr("it.rename"), { app.close() }, footer = { GBtn(tr("common.save"), ::save, enabled = err == null) }) {
        GField(tr("ws.name"), v, { v = it }, error = err, showError = true, imeAction = ImeAction.Done, onIme = ::save, focusRequester = fr)
    }
}

@Composable
private fun ItemMove(s: Sheet.ItemMove) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val (w, it) = app.item(s.pid, s.wid, s.iid) ?: run { app.close(); return }
    val others = p.floors.filter { it.id != w.id }
    GlassSheet(tr("it.moveT"), { app.close() }) {
        if (others.isEmpty()) Text(tr("it.moveNone"), style = ui(14f, 400, G.ink2, 1.4f), modifier = Modifier.padding(bottom = 8.dp))
        else ListBox {
            others.forEachIndexed { i, to ->
                if (i > 0) Hairline()
                ActionRow(wsIcon(to.type), floorName(to, lang), {
                    app.store.update(p.id) { pr -> pr.copy(floors = pr.floors.map { x ->
                        when (x.id) { w.id -> x.copy(items = x.items.filter { y -> y.id != it.id }); to.id -> x.copy(items = x.items + it); else -> x }
                    }) }
                    app.close(); app.dropMissing()
                    app.say("it.moved", "n" to itemName(it, lang), "w" to floorName(to, lang))
                }, trailing = { MIcon("chev", G.ink3, 18.dp, 2f) })
            }
        }
    }
}

/** The currency new projects start with (prototype SHEETS.currency). */
@Composable
private fun CurrencySheet() {
    val app = LocalApp.current
    GlassSheet(tr("np.currency"), { app.close() }) {
        listOf("UZS", "USD", "EUR", "RUB").forEach { c ->
            val on = app.settings.currency == c
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp))
                    .background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
                    .border(1.dp, if (on) G.cobalt.copy(alpha = .5f) else G.idleRim, RoundedCornerShape(16.dp))
                    .clickable(role = Role.RadioButton) { app.settings.setCurrencyDefault(c); app.close() }.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(c + if (c == "UZS") " (${tr("cur.UZS")})" else "", style = ui(16f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f))
                if (on) MIcon("check", G.cobalt2, 20.dp, 2.4f)
            }
        }
        Text(tr("se.curNote"), style = ui(13f, 400, G.ink2, 1.4f))
    }
}

