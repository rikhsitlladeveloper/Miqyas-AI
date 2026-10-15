package uz.metrx.app.ui.editor

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.L_SHAPE
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.dimMax
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.geo.parseDec
import uz.metrx.app.geo.polyDims
import uz.metrx.app.geo.unconfCount
import uz.metrx.app.geo.unitDecimals
import uz.metrx.app.geo.wallCorner
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.ActionRow
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.ListBox
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/** The editor's sheets. Returns false for sheets it doesn't own. */
@Composable
fun EditorSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.NewRoom -> NewRoomSheet(s)
        is Sheet.Measure -> MeasureSheet(s)
        is Sheet.AddOpening -> AddOpeningSheet(s)
        is Sheet.OpeningForm -> OpeningSheet(s)
        is Sheet.RoomInfo -> RoomInfoSheet(s)
        is Sheet.RoomRename -> RenameSheet(s)
        is Sheet.Tray -> TraySheet(s)
        is Sheet.RoomMenu -> RoomMenuSheet(s)
        is Sheet.RoomMove -> RoomMoveSheet(s)
        is Sheet.WallAdd -> WallAddSheet(s)
        else -> return false
    }
    return true
}

private fun App.close() { sheet = null }

/** The error text for a parse result, or null. */
@Composable
internal fun errText(p: Parsed?): String? = (p as? Parsed.Err)?.let { e -> tr(e.key, *e.vars.map { (k, v) -> k to (if (v is String && v.contains("@u.")) v.replace("@u.cm", tr("u.cm")).replace("@u.m", tr("u.m")) else v) }.toTypedArray()) }

/**
 * A number field like the prototype's .box.num: condensed 19/600 digits, a unit after them, the phone's decimal keyboard.
 */
@Composable
fun NumField(label: String?, value: String, onValue: (String) -> Unit, suffix: String, error: String?, showError: Boolean,
             onBlur: () -> Unit = {}, imeAction: ImeAction = ImeAction.Next, onIme: () -> Unit = {}, focusRequester: FocusRequester = remember { FocusRequester() },
             modifier: Modifier = Modifier) {
    var focused by remember { mutableStateOf(false) }
    val bad = showError && error != null
    val shape = RoundedCornerShape(16.dp)
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (label != null) Text(label, style = ui(15f, 700), maxLines = 2)
        Row(
            Modifier.fillMaxWidth()
                .drawBehind { if (focused) { val o = 4.dp.toPx(); drawRoundRect((if (bad) G.err else G.cobalt).copy(alpha = .12f), Offset(-o / 2, -o / 2), Size(size.width + o, size.height + o), CornerRadius(16.dp.toPx() + o / 2), style = Stroke(o)) } }
                .clip(shape).background(G.glass(.6f)).border(if (focused || bad) 2.dp else 1.dp, if (bad) G.err else if (focused) G.cobalt else G.rim, shape)
                .heightIn(min = 56.dp).padding(horizontal = 17.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            BasicTextField(value, onValue, singleLine = true, textStyle = num(19f, 600), cursorBrush = SolidColor(G.cobalt),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = imeAction),
                keyboardActions = KeyboardActions(onAny = { onIme() }),
                modifier = Modifier.weight(1f).padding(vertical = 10.dp).focusRequester(focusRequester)
                    .onFocusChanged { if (focused && !it.isFocused) onBlur(); focused = it.isFocused }
                    .semantics { contentDescription = label ?: suffix })
            Text(suffix, style = ui(15f, 400, G.ink2))
        }
        if (bad) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { MIcon("alert", G.err, 18.dp, 2f); Text(error!!, style = ui(13.5f, 500, G.err)) }
    }
}

/* ---------------- a new room: name and shape (prototype SHEETS.newRoom) ---------------- */

@Composable
private fun NewRoomSheet(s: Sheet.NewRoom) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val w = p.floors.firstOrNull { it.id == s.wid } ?: run { app.close(); return }
    val own = w.type in listOf("room", "bath", "kitchen", "balcony") && p.rooms.none { it.floorId == w.id }
    var name by rememberSaveable { mutableStateOf(if (own) floorName(w, lang) else app.t("real.roomN", "n" to p.rooms.size + 1)) }
    val err = if (name.isBlank()) tr("nr.nameReq") else null
    fun create(shape: String) {
        if (name.isBlank()) return
        val now = System.currentTimeMillis()
        val r = when (shape) {
            "lshape" -> Room(uid(), w.id, name.trim(), template = "poly", shape = "poly", dims = polyDims(L_SHAPE.size), poly = Poly(L_SHAPE, template = "lshape"), created = now)
            else -> Room(uid(), w.id, name.trim(), created = now)
        }
        app.store.update(p.id) { it.copy(rooms = it.rooms + r) }
        app.close()
        app.push(Route.Editor(p.id, r.id))
        if (shape == "lshape") app.say("sk.created", "n" to 6) else app.ops.focus(r.id, "A")
    }
    GlassSheet(tr("nr.title"), { app.close() }, footer = { GBtn(tr("nr.create"), { create("rect") }, enabled = err == null) }) {
        GField(tr("nr.name"), name, { name = it }, tr("smp.living"), error = err, showError = true, imeAction = ImeAction.Done, onIme = { create("rect") })
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("nr.shape"), style = ui(15f, 700))
            ShapeRow("M2 2H32V24H2Z", tr("nr.rect"), true) {}
            ShapeRow("M2 2H18V12H32V24H2Z", tr("nr.lshape"), false) { create("lshape") }
            ShapeRow("M3 22L6 3L25 6L31 19Z", tr("nr.sketch"), false) { if (name.isNotBlank()) { app.close(); app.push(Route.Sketch(p.id, w.id, name.trim())) } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 17.dp, 2f); Text(tr("nr.hint"), style = ui(13f, 400, G.ink2, 1.4f)) }
    }
}

@Composable
private fun ShapeRow(d: String, label: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier.fillMaxWidth().heightIn(min = 49.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .12f) else G.glass(.55f))
            .border(1.dp, if (on) G.cobalt else G.rim, shape).clickable(enabled = !on, role = Role.Button, onClick = onClick).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        uz.metrx.app.ui.icons.PathIcon(d, if (on) G.cobalt2 else G.ink, 30.dp, 2f, viewBox = 34f)
        Text(label, style = ui(15f, if (on) 600 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f))
        MIcon(if (on) "check" else "chev", if (on) G.cobalt2 else G.ink, 17.dp, 2f)
    }
}

/* ---------------- typing a measurement (prototype SHEETS.measure, manual) ---------------- */

@Composable
private fun MeasureSheet(s: Sheet.Measure) {
    val app = LocalApp.current
    val ops = app.ops
    val r = ops.room(s.pid, s.rid) ?: run { app.close(); return }
    val unit = app.settings.unit; val en = app.english()
    val d = r.dim(s.k)
    val title = when { s.k == "H" -> tr("ed.H"); s.k == "T" -> tr("ed.T"); s.k.startsWith("X") -> tr("sk.diagName", "d" to s.k); else -> tr("ed.wallLen", "w" to s.k) }
    var v by rememberSaveable { mutableStateOf("") }
    var touched by remember { mutableStateOf(false) }
    val parsed = lenErr(v, dimMax(s.k), unit, en)
    val err = errText(parsed)
    val fr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    fun save() { touched = true; val ok = parsed as? Parsed.Ok ?: return; ops.apply(s.pid, s.rid, s.k, ok.value.toInt(), "manual") }
    GlassSheet(title, { app.close() }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.cancel"), { app.close() }, Btn.SECONDARY, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = parsed is Parsed.Ok, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
        }
    }) {
        if (!ops.laserOn) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MIcon("btoff", AMBER, 18.dp, 2f)
            Text(tr("ms.discBody"), style = ui(13.5f, 500, AMBER, 1.35f), modifier = Modifier.weight(1f))
            Text(tr("ms.connect"), style = ui(14f, 700, G.cobalt), modifier = Modifier.clickable(role = Role.Button) { app.sheet = Sheet.Device }.padding(6.dp))
        }
        NumField(title, v, { v = it }, app.unitName(), err, touched && v.isNotEmpty() || touched, onBlur = { touched = true }, imeAction = ImeAction.Done, onIme = ::save, focusRequester = fr)
        Text(tr("ms.hint", "ex" to fmtLen(4255, unit, en)), style = ui(13f, 400, G.ink2))
        Text(tr("ms.current", "v" to if (d.v != null) fmtLen(d.v, unit, en, true) + " " + app.unitName() + " (" + tr("src.${d.src ?: "manual"}") + ")" else tr("ms.none")), style = ui(13f, 400, G.ink2))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 17.dp, 2f); Text(tr("ms.manualNote"), style = ui(13f, 400, G.ink2, 1.4f)) }
        if (ops.laserOn) Row(Modifier.heightIn(min = 44.dp).clickable(role = Role.Button) { app.close(); ops.laser(s.pid, s.rid, s.k) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            MIcon("laser", G.cobalt, 18.dp, 2f); Text(tr("ms.useLaser"), style = ui(14f, 600, G.cobalt))
        }
    }
}

/* ---------------- doors and windows ---------------- */

@Composable
private fun AddOpeningSheet(s: Sheet.AddOpening) {
    val app = LocalApp.current
    val ops = app.ops
    val r = ops.room(s.pid, s.rid) ?: run { app.close(); return }
    val unit = app.settings.unit; val en = app.english()
    GlassSheet(tr("ao.title"), { app.close() }) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            BigOpt("door", tr("op.door"), null, Modifier.weight(1f)) { app.sheet = Sheet.OpeningForm(s.pid, s.rid, null, "door") }
            BigOpt("window", tr("op.window"), null, Modifier.weight(1f)) { app.sheet = Sheet.OpeningForm(s.pid, s.rid, null, "window") }
            BigOpt("column", tr("ao.col"), tr("nr.later"), Modifier.weight(1f)) { app.say("nr.later", kind = ToastKind.INFO) }
        }
        Text(tr("ao.here"), style = ui(13f, 500, G.ink2), modifier = Modifier.padding(top = 8.dp))
        if (r.openings.isEmpty()) Text(tr("ao.none"), style = ui(13f, 400, G.ink2))
        else ListBox {
            r.openings.forEachIndexed { i, o ->
                if (i > 0) Hairline()
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable { app.sheet = Sheet.OpeningForm(s.pid, s.rid, o.id) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    MIcon(o.type, G.cobalt, 20.dp, 2f)
                    Text(ops.opName(o) + ", " + tr("op.wall") + " " + o.wall, style = ui(15f, 600), modifier = Modifier.weight(1f))
                    Text(fmtLen(o.w, unit, en) + " × " + fmtLen(o.h, unit, en) + " " + app.unitName(), style = num(14.5f, 600, G.ink2))
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
            }
        }
    }
}

@Composable
private fun BigOpt(icon: String, label: String, sub: String?, modifier: Modifier, onClick: () -> Unit) {
    Column(modifier.heightIn(min = 127.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .06f)).pressable(onClick, .97f).padding(start = 6.dp, end = 6.dp, top = 14.dp, bottom = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        MIcon(icon, G.cobalt, 30.dp, 2f)
        Text(label, style = ui(14f, 600), textAlign = TextAlign.Center)
        if (sub != null) Text(sub, style = ui(11.5f, 400, G.ink2))
    }
}

/** A door or window: type, wall, a small drawing of the wall, size, offset and sill (prototype SHEETS.opening). */
@Composable
private fun OpeningSheet(s: Sheet.OpeningForm) {
    val app = LocalApp.current
    val ops = app.ops
    val r = ops.room(s.pid, s.rid) ?: run { app.close(); return }
    val unit = app.settings.unit; val en = app.english(); val dec = unitDecimals(unit)
    val snap = app.settings.angleSnap
    val edit = s.oid?.let { id -> r.openings.firstOrNull { it.id == id } }
    val st = app.settings
    val ws = walls(r, snap)
    var type by rememberSaveable { mutableStateOf(edit?.type ?: s.type) }
    var wall by rememberSaveable { mutableStateOf(edit?.wall ?: s.wall ?: if (s.type == "door") "A" else ws.getOrNull(2)?.id ?: "A") }
    fun defOff(t: String, wl: String): Int {
        if (t == "door") return 500
        val L = ws.firstOrNull { it.id == wl }?.len
        return if (L != null) maxOf(0, Math.round((L - st.winW) / 2.0 / 10).toInt() * 10) else 1000
    }
    var wv by rememberSaveable { mutableStateOf(fmtField(edit?.w ?: if (type == "door") st.doorW else st.winW, unit, en)) }
    var hv by rememberSaveable { mutableStateOf(fmtField(edit?.h ?: if (type == "door") st.doorH else st.winH, unit, en)) }
    var offv by rememberSaveable { mutableStateOf(fmtField(edit?.off ?: defOff(type, wall), unit, en)) }
    var sillv by rememberSaveable { mutableStateOf(fmtField(edit?.sill ?: if (type == "door") 0 else st.winSill, unit, en)) }
    var tried by remember { mutableStateOf(false) }
    fun setType(t: String) {
        if (t == type) return
        type = t
        wv = fmtField(if (t == "door") st.doorW else st.winW, unit, en); hv = fmtField(if (t == "door") st.doorH else st.winH, unit, en)
        offv = fmtField(defOff(t, wall), unit, en); sillv = fmtField(if (t == "door") 0 else st.winSill, unit, en)
    }
    val pw = lenErr(wv, dimMax("A"), unit, en); val ph = lenErr(hv, dimMax("H"), unit, en)
    val po = parseDec(offv, dec); val ps = if (type == "window") parseDec(sillv, dec) else Parsed.Ok(0)
    val fieldsOk = pw is Parsed.Ok && ph is Parsed.Ok && po is Parsed.Ok && ps is Parsed.Ok
    val o = if (fieldsOk) Opening(edit?.id ?: "new", type, wall, (pw as Parsed.Ok).value.toInt(), (ph as Parsed.Ok).value.toInt(), (po as Parsed.Ok).value.toInt(), (ps as Parsed.Ok).value.toInt()) else null
    val iss = o?.let { ops.issue(r, it) }
    val corner = wallCorner(r, wall, snap)
    fun save() { tried = true; if (o == null || iss != null) return; ops.saveOpening(s.pid, s.rid, if (edit == null) o.copy(id = uid()) else o, edit == null) }
    val title = tr(if (edit != null) (if (type == "door") "op.door" else "op.window") else if (type == "door") "op.new.door" else "op.new.window")
    GlassSheet(title, { app.close() }, footer = {
        if (edit?.approx == true) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", AMBER, 18.dp, 2f); Text(tr("op.approx"), style = ui(13.5f, 500, AMBER, 1.35f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (edit != null) GBtn(tr("common.delete"), { ops.deleteOpening(s.pid, s.rid, edit) }, Btn.DANGER, icon = "trash", height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            else GBtn(tr("common.cancel"), { app.close() }, Btn.SECONDARY, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = fieldsOk && iss == null, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
        }
    }) {
        if (edit == null) Seg(listOf("door" to tr("op.door"), "window" to tr("op.window")), type) { setType(it) }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("op.wall"), style = ui(15f, 700))
            Seg(ws.map { it.id to it.id }, wall, subs = ws.associate { it.id to fmtLen(it.len, unit, en) }) { wall = it; if (edit == null) offv = fmtField(defOff(type, it), unit, en) }
        }
        WallDiagram(o, ws.firstOrNull { it.id == wall }?.len, corner, ws.size, iss != null)
        Text(tr("op.offsetHelp", "c" to corner), style = ui(13f, 400, G.ink2))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("op.width"), wv, { wv = it }, app.unitName(), errText(pw), tried, modifier = Modifier.weight(1f))
            NumField(tr("op.height"), hv, { hv = it }, app.unitName(), errText(ph), tried, modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("op.offset", "c" to corner), offv, { offv = it }, app.unitName(), errText(po), tried, modifier = Modifier.weight(1f))
            if (type == "window") NumField(tr("op.sill"), sillv, { sillv = it }, app.unitName(), errText(ps), tried, modifier = Modifier.weight(1f))
            else Spacer(Modifier.weight(1f))
        }
        if (fieldsOk && iss != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.err, 18.dp, 2f); Text(app.t(iss.key, *iss.vars.toList().toTypedArray()), style = ui(13.5f, 500, G.err, 1.35f))
        }
    }
}

/** A segmented control (prototype .seg.wide) with an optional small value under each label. */
@Composable
internal fun Seg(items: List<Pair<String, String>>, cur: String, subs: Map<String, String> = emptyMap(), onPick: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        items.forEach { (k, label) ->
            val on = k == cur
            Column(
                Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(9.dp)).background(if (on) G.glass(.9f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 6.dp, vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
            ) {
                Text(label, style = ui(14f, if (on) 600 else 500, if (on) G.ink else G.ink2), maxLines = 1)
                subs[k]?.let { Text(it, style = num(11.5f, 400, if (on) G.ink else G.ink2)) }
            }
        }
    }
}

/** The wall as a line from its start corner, the opening in place and an arrow for the offset (prototype .minidia, 320 × 54). */
@Composable
private fun WallDiagram(o: Opening?, L: Int?, corner: Int, n: Int, bad: Boolean) {
    val tm = rememberTextMeasurer()
    Canvas(Modifier.fillMaxWidth().height(74.dp).clip(RoundedCornerShape(12.dp)).border(1.dp, G.rim, RoundedCornerShape(12.dp)).padding(6.dp)) {
        val k = minOf(size.width / 320f, size.height / 54f)
        val ox = (size.width - 320f * k) / 2f; val oy = (size.height - 54f * k) / 2f
        translate(ox, oy) {
            scale(k, k, pivot = Offset.Zero) {
                drawLine(INK, Offset(20f, 30f), Offset(300f, 30f), 6f)
                drawCircle(COB, 5f, Offset(20f, 30f))
                text(tm, "$corner", Offset(20f, 13f), androidx.compose.ui.text.TextStyle(fontFamily = uz.metrx.app.ui.theme.Jakarta, fontSize = androidx.compose.ui.unit.TextUnit(11f, androidx.compose.ui.unit.TextUnitType.Sp), fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, color = COB))
                text(tm, "${corner % n + 1}", Offset(300f, 13f), androidx.compose.ui.text.TextStyle(fontFamily = uz.metrx.app.ui.theme.Jakarta, fontSize = androidx.compose.ui.unit.TextUnit(11f, androidx.compose.ui.unit.TextUnitType.Sp), color = INK3))
                if (o != null) {
                    val sx = 280f / (L ?: 5000)
                    val x = 20f + o.off * sx; val w = maxOf(2f, o.w * sx)
                    drawRect(PLAN_W, Offset(x, 25f), Size(w, 10f))
                    drawRect(if (bad) RED else COB, Offset(x, 25f), Size(w, 10f), style = Stroke(1.5f))
                    drawLine(COB, Offset(20f, 46f), Offset(x, 46f), 1.2f)
                    drawLine(COB, Offset(x - 5f, 43f), Offset(x, 46f), 1.2f); drawLine(COB, Offset(x - 5f, 49f), Offset(x, 46f), 1.2f)
                }
            }
        }
    }
}

/* ---------------- room information (prototype SHEETS.roomInfo) ---------------- */

@Composable
private fun RoomInfoSheet(s: Sheet.RoomInfo) {
    val app = LocalApp.current
    val ops = app.ops
    val lang = LocalLang.current
    val r = ops.room(s.pid, s.rid) ?: run { app.close(); return }
    val unit = app.settings.unit; val en = app.english(); val m = app.unitName()
    val a = areas(r, app.settings.angleSnap)
    val H = r.dim("H").v
    val n = unconfCount(r, app.settings.angleSnap)
    GlassSheet(dn(r.name, lang), { app.close() }) {
        ListBox {
            Kv(tr("rp.floorArea"), a?.let { fmtArea(it.floor, en) + " m²" } ?: "—")
            Hairline(); Kv(tr("rp.perim"), a?.let { fmtLen(it.perim.toInt(), unit, en) + " " + m } ?: "—")
            Hairline(); Kv(tr("ri.height"), if (H != null) fmtLen(H, unit, en) + " " + m else "—")
            Hairline(); Kv(tr("rp.gross"), a?.gross?.let { fmtArea(it, en) + " m²" } ?: "—")
            Hairline(); Kv(tr("rp.openings"), a?.open?.let { fmtArea(it, en) + " m²" } ?: "—")
            Hairline(); Kv(tr("rp.net"), a?.net?.let { fmtArea(it, en) + " m²" } ?: "—")
            Hairline(); Kv(tr("ri.volume"), if (a != null && H != null) "%.2f".format(java.util.Locale.ROOT, a.floor.toDouble() * H / 1e9).replace('.', if (en) '.' else ',') + " m³" else "—", bold = true)
        }
        if (n > 0 && a != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("clock", AMBER, 18.dp, 2f); Text(tr("rp.prov", "n" to n), style = ui(13.5f, 500, AMBER))
        }
        Text(tr("rp.conv") + " " + tr("ri.volNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
        ListBox {
            ActionRow("edit", tr("ri.rename"), { app.sheet = Sheet.RoomRename(s.pid, s.rid) })
            Hairline()
            ActionRow("walls", tr("ri.walls"), { app.close(); app.push(Route.WallView(s.pid, s.rid, walls(r, app.settings.angleSnap).first().id)) })
            if (!r.isPoly) { Hairline(); ActionRow("redo", tr("ri.rotate"), { ops.rotate(s.pid, s.rid) }) }
            Hairline()
            ActionRow("trash", tr("ri.delete"), { ops.deleteRoom(s.pid, s.rid) }, danger = true)
        }
    }
}

@Composable
private fun Kv(label: String, value: String, bold: Boolean = false) {
    Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = ui(14f, if (bold) 700 else 400, G.ink), modifier = Modifier.weight(1f))
        Text(value, style = num(15f, if (bold) 700 else 600))
    }
}

@Composable
private fun RenameSheet(s: Sheet.RoomRename) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val r = app.ops.room(s.pid, s.rid) ?: run { app.close(); return }
    var v by rememberSaveable { mutableStateOf(dn(r.name, lang)) }
    val err = if (v.isBlank()) tr("nr.nameReq") else null
    val fr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    fun save() { if (err == null) app.ops.rename(s.pid, s.rid, v) }
    GlassSheet(tr("room.rename"), { app.close() }, footer = { GBtn(tr("common.save"), ::save, enabled = err == null) }) {
        GField(tr("nr.name"), v, { v = it }, error = err, showError = true, imeAction = ImeAction.Done, onIme = ::save, focusRequester = fr)
    }
}

/** The readings tray: readings taken on the Measure tab (part 7) wait here to be given to a wall. */
@Composable
private fun TraySheet(s: Sheet.Tray) {
    val app = LocalApp.current
    val en = LocalLang.current == uz.metrx.app.core.Lang.EN
    val r = app.ops.room(s.pid, s.rid) ?: run { app.close(); return }
    val rs = app.settings.readings.reversed()
    val targets = uz.metrx.app.geo.stepKeys(r, app.settings.angleSnap) + "T"
    GlassSheet(tr("tr.title"), { app.close() }) {
        Text(tr("tr.body"), style = ui(14f, 400, G.ink2, 1.45f))
        if (app.settings.laser == uz.metrx.app.core.Laser.CONNECTED)
            GBtn(tr("ms.simPress"), { app.ops.trayReading(s.pid, s.rid) }, kind = uz.metrx.app.ui.components.Btn.SECONDARY, icon = "laser")
        else Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("btoff", G.amberInk, 18.dp, 2f)
            Text(tr("ms.discBody"), style = ui(13.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f))
            Text(tr("ms.connect"), style = ui(14f, 700, G.cobalt), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable { app.sheet = Sheet.Device }.padding(horizontal = 8.dp, vertical = 12.dp))
        }
        if (rs.isEmpty()) Text(tr("tr.empty"), style = ui(14f, 500, G.ink2, 1.45f))
        rs.forEach { x ->
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).padding(horizontal = 12.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(fmtLen(x.mm, app.settings.unit, en, full = true) + " " + app.unitName(), style = ui(20f, 600).copy(fontFamily = uz.metrx.app.ui.theme.PlexCond), modifier = Modifier.weight(1f))
                    Text(tr(if (x.src == "manual") "src.manual" else "src.sim"), style = ui(12.5f, 500, G.ink2))
                }
                if (x.used != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    MIcon("check", G.green, 14.dp, 2.4f); Text(tr("tr.used", "d" to x.used), style = ui(13f, 400, G.ink2))
                } else @OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class) androidx.compose.foundation.layout.FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp), itemVerticalAlignment = Alignment.CenterVertically) {
                    Text(tr("tr.assign"), style = ui(13f, 400, G.ink2))
                    targets.forEach { k ->
                        Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.7f)).border(1.dp, G.rim, RoundedCornerShape(12.dp))
                            .clickable { app.ops.assignReading(s.pid, s.rid, x.id, k) }.padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
                            Text(if (k == "H") tr("ed.Hs") else if (k == "T") tr("ed.Ts") else k, style = ui(14f, 600))
                        }
                    }
                }
            }
        }
    }
}


/** A room card's menu (prototype SHEETS.itemMenu for rooms). */
@Composable
private fun RoomMenuSheet(s: Sheet.RoomMenu) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val r = p.rooms.firstOrNull { it.id == s.rid } ?: run { app.close(); return }
    val rep = p.reportRooms[r.id] != false
    GlassSheet(dn(r.name, lang), { app.close() }) {
        ListBox {
            ActionRow("edit", tr("it.rename"), { app.sheet = Sheet.RoomRename(s.pid, s.rid) })
            Hairline()
            ActionRow("layers", tr("it.move"), { app.sheet = Sheet.RoomMove(s.pid, s.rid) })
            Hairline()
            ActionRow("copy", tr("it.dup"), {
                val copy = r.copy(id = uid(), name = app.t("room.copy", "n" to dn(r.name, lang)), created = System.currentTimeMillis(), views = emptyList(),
                    openings = r.openings.map { it.copy(id = uid()) })
                app.store.update(s.pid) { it.copy(rooms = it.rooms + copy) }
                app.close(); app.say("op.added", "o" to dn(copy.name, lang))
            })
            Hairline()
            ActionRow("doc", tr("it.report"), { app.store.update(s.pid) { it.copy(reportRooms = it.reportRooms + (r.id to !rep)) } },
                trailing = { uz.metrx.app.ui.components.GSwitch(rep) })
            Hairline()
            ActionRow("trash", tr("it.del"), { app.ops.deleteRoom(s.pid, s.rid) }, danger = true)
        }
    }
}

@Composable
private fun RoomMoveSheet(s: Sheet.RoomMove) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.close(); return }
    val r = p.rooms.firstOrNull { it.id == s.rid } ?: run { app.close(); return }
    val others = p.floors.filter { it.id != r.floorId }
    GlassSheet(tr("it.moveT"), { app.close() }) {
        if (others.isEmpty()) Text(tr("it.moveNone"), style = ui(14f, 400, G.ink2, 1.4f), modifier = Modifier.padding(bottom = 8.dp))
        else ListBox {
            others.forEachIndexed { i, to ->
                if (i > 0) Hairline()
                ActionRow(uz.metrx.app.data.wsIcon(to.type), floorName(to, lang), {
                    app.store.update(s.pid) { pr -> pr.copy(rooms = pr.rooms.map { if (it.id == r.id) it.copy(floorId = to.id) else it }) }
                    app.close(); app.say("it.moved", "n" to dn(r.name, lang), "w" to floorName(to, lang))
                }, trailing = { MIcon("chev", G.ink3, 18.dp, 2f) })
            }
        }
    }
}

/** Add on one wall (prototype SHEETS.wvAdd): a door or a window with the default sizes. */
@Composable
private fun WallAddSheet(s: Sheet.WallAdd) {
    val app = LocalApp.current
    val st = app.settings; val unit = st.unit; val en = app.english()
    GlassSheet(tr("wv.add"), { app.close() }) {
        Text(tr("wv.onWall", "w" to s.wall), style = ui(13.5f, 400, G.ink2, 1.4f))
        ListBox {
            ActionRow("door", tr("op.door") + "  ·  " + fmtLen(st.doorW, unit, en) + " × " + fmtLen(st.doorH, unit, en), { app.sheet = Sheet.OpeningForm(s.pid, s.rid, null, "door", s.wall) },
                trailing = { MIcon("chev", G.ink3, 18.dp, 2f) })
            Hairline()
            ActionRow("window", tr("op.window") + "  ·  " + fmtLen(st.winW, unit, en) + " × " + fmtLen(st.winH, unit, en), { app.sheet = Sheet.OpeningForm(s.pid, s.rid, null, "window", s.wall) },
                trailing = { MIcon("chev", G.ink3, 18.dp, 2f) })
        }
    }
}
