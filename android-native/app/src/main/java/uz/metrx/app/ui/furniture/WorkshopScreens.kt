package uz.metrx.app.ui.furniture

import androidx.compose.foundation.background
import uz.metrx.app.ui.components.switchState
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.uid
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Hw
import uz.metrx.app.furniture.Insert
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.costOf
import uz.metrx.app.furniture.cutList
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigInteger

/*
 * Stage 1a part 3 (furniture plan sections 6.2, 6.6, 6.7; design canvas screens 12 and 13): the workshop's construction
 * and price rules, and its boards and hardware, in Profile. A sample unit shows what the rules make.
 */

/** A workshop value: how it is typed and shown. mm = whole mm, mm10 = tenths of a mm, pct, money. */
private enum class WKind { MM, MM10, PCT, MONEY }

private data class WField(val key: String, val label: String, val kind: WKind, val get: (Workshop) -> String, val set: (Workshop, String) -> Workshop)

private val FIELDS = listOf(
    WField("gap", "wk.gap", WKind.MM10, { it.gap10.toString() }, { w, v -> w.copy(gap10 = v.toInt()) }),
    WField("edge", "wk.edge", WKind.MM10, { it.edge10.toString() }, { w, v -> w.copy(edge10 = v.toInt()) }),
    WField("band", "wk.band", WKind.MM10, { it.band10.toString() }, { w, v -> w.copy(band10 = v.toInt()) }),
    WField("legH", "wk.legH", WKind.MM, { it.legH.toString() }, { w, v -> w.copy(legH = v.toInt()) }),
    WField("sheetL", "wk.sheetL", WKind.MM, { it.sheetL.toString() }, { w, v -> w.copy(sheetL = v.toInt()) }),
    WField("sheetW", "wk.sheetW", WKind.MM, { it.sheetW.toString() }, { w, v -> w.copy(sheetW = v.toInt()) }),
    WField("kerf", "wk.kerf", WKind.MM, { it.kerf.toString() }, { w, v -> w.copy(kerf = v.toInt()) }),
    WField("trim", "wk.trim", WKind.MM, { it.trim.toString() }, { w, v -> w.copy(trim = v.toInt()) }),
    WField("margin", "wk.margin", WKind.PCT, { it.margin.toString() }, { w, v -> w.copy(margin = v.toInt()) }),
    WField("prepay", "wk.prepay", WKind.PCT, { it.prepay.toString() }, { w, v -> w.copy(prepay = v.toInt()) }),
    WField("rCut", "wk.rCut", WKind.MONEY, { it.rCut }, { w, v -> w.copy(rCut = v) }),
    WField("rBand", "wk.rBand", WKind.MONEY, { it.rBand }, { w, v -> w.copy(rBand = v) }),
    WField("rAsm", "wk.rAsm", WKind.MONEY, { it.rAsm }, { w, v -> w.copy(rAsm = v) }),
    WField("rInstall", "wk.rInstall", WKind.MONEY, { it.rInstall }, { w, v -> w.copy(rInstall = v) }),
    WField("rDeliver", "wk.rDeliver", WKind.MONEY, { it.rDeliver }, { w, v -> w.copy(rDeliver = v) })
)

/** Tenths of a mm as "1,5", or a stored value as it is shown. */
private fun tenths(v: Int, en: Boolean) = if (v % 10 == 0) "${v / 10}" else "${v / 10}${if (en) '.' else ','}${v % 10}"

@Composable
private fun shown(f: WField, w: Workshop): String {
    val app = LocalApp.current; val en = LocalLang.current == Lang.EN
    val raw = f.get(w)
    return when (f.kind) {
        WKind.MM10 -> tenths(raw.toInt(), en) + " mm"
        WKind.MM -> "$raw mm"
        WKind.PCT -> "$raw %"
        WKind.MONEY -> moneyStr(raw.toBigIntegerOrNull() ?: BigInteger.ZERO, 0, en) + " " + curSuffix(app.settings.currency, LocalLang.current)
    }
}

/** A sub-page with a back button and a title (as Profile's More settings). */
@Composable
private fun Page(title: String, content: @Composable () -> Unit) {
    val app = LocalApp.current
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }); Text(title, style = ui(17f, 700), modifier = Modifier.weight(1f))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { content() }
    }
}

@Composable
private fun Card(title: String, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(start = 14.dp, end = 10.dp, top = 12.dp, bottom = 4.dp)) {
        Text(title, style = ui(15f, 800), modifier = Modifier.padding(bottom = 4.dp))
        content()
    }
}

@Composable
private fun ValRow(label: String, value: String, onClick: () -> Unit) {
    Hairline()
    Row(Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable(role = Role.Button, onClick = onClick).padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = ui(14.5f, 500), modifier = Modifier.weight(1f))
        Text(value, style = num(14.5f, 700), maxLines = 1)
        MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

/* ---------------- workshop settings ---------------- */

@Composable
fun WorkshopScreen() {
    val app = LocalApp.current
    val s = app.settings
    val w = s.workshop
    val lang = LocalLang.current; val en = lang == Lang.EN
    fun f(k: String) = FIELDS.first { it.key == k }
    Page(tr("wk.title")) {
        Card(tr("wk.build")) {
            Hairline()
            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("wk.t"), style = ui(14.5f, 500), modifier = Modifier.weight(1f))
                Box(Modifier.size(150.dp, 48.dp)) { Seg(listOf("16" to "16 mm", "18" to "18 mm"), w.t.toString()) { s.setWorkshopRules(w.copy(t = it.toInt())) } }
            }
            Hairline()
            Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tr("wk.back"), style = ui(14.5f, 500))
                Seg(listOf("nail" to tr("wk.nail"), "groove" to tr("wk.groove")), w.back) { s.setWorkshopRules(w.copy(back = it)) }
            }
            listOf("gap", "edge", "band", "legH").forEach { k -> ValRow(tr(f(k).label), shown(f(k), w)) { app.sheet = Sheet.WsField(k) } }
            Hairline()
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).switchState(w.bandOff).clickable(role = Role.Switch) { s.setWorkshopRules(w.copy(bandOff = !w.bandOff)) }.padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(tr("wk.bandOff"), style = ui(14.5f, 500), modifier = Modifier.weight(1f)); GSwitch(w.bandOff)
            }
        }
        Card(tr("wk.sheet")) { listOf("sheetL", "sheetW", "kerf", "trim").forEach { k -> ValRow(tr(f(k).label), shown(f(k), w)) { app.sheet = Sheet.WsField(k) } } }
        Card(tr("wk.price")) { listOf("margin", "prepay", "rCut", "rBand", "rAsm", "rInstall", "rDeliver").forEach { k -> ValRow(tr(f(k).label), shown(f(k), w)) { app.sheet = Sheet.WsField(k) } } }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 16.dp, 2f); Text(tr("wk.note"), style = ui(13f, 400, G.ink2, 1.4f)) }
        SampleCard(w, en)
    }
}

/** The sample unit with today's rules: its parts with finished and cut sizes, and what it costs. */
@Composable
private fun SampleCard(w: Workshop, en: Boolean) {
    val app = LocalApp.current
    val m = Module("s", "base", 600, 720, 560, fronts = Fronts("door", 2), inserts = listOf(Insert("shelf", qty = 1)), label = "600")
    val f = Furniture("s", "kitchen", modules = listOf(m))
    val rows = cutList(listOf(f), w)
    val cost = costOf(listOf(f), w, app.settings.mats, app.settings.hws, order = false)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("wk.sample"), style = ui(15f, 800))
        Text(tr("wk.sampleS"), style = ui(12.5f, 400, G.ink2))
        rows.forEach { r ->
            Hairline()
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(tr(r.p.key), style = ui(13.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(app.settings.mats.firstOrNull { it.id == r.mat }?.name ?: r.mat, style = ui(11.5f, 400, G.ink2), maxLines = 1)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("${r.p.L} × ${r.p.W} × ${r.p.qty}", style = num(13.5f, 700))
                    if (r.cutL != r.p.L || r.cutW != r.p.W) Text(tr("wk.cut", "v" to "${r.cutL} × ${r.cutW}"), style = ui(11.5f, 400, G.ink2))
                }
            }
        }
        Hairline()
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tr("wk.cost"), style = ui(14f, 600), modifier = Modifier.weight(1f))
            Text(moneyStr(cost.total, 0, en) + " " + curSuffix(app.settings.currency, LocalLang.current), style = num(16f, 800))
        }
    }
}

/* ---------------- materials and hardware ---------------- */

@Composable
fun MaterialsScreen() {
    val app = LocalApp.current
    val s = app.settings
    val en = LocalLang.current == Lang.EN
    var tab by rememberSaveable { mutableStateOf("m") }
    Page(tr("wk.mats")) {
        Seg(listOf("m" to tr("mt.mats") + " · " + s.mats.size, "h" to tr("mt.hws") + " · " + s.hws.size), tab) { tab = it }
        Text(tr("mt.lead"), style = ui(12.5f, 400, G.ink2, 1.45f))
        if (tab == "m") s.mats.forEach { m ->
            ItemRow(Color(android.graphics.Color.parseColor(m.rgb)), m.name, matSub(m), priceOf(m.price, en), unitOf(m)) { app.sheet = Sheet.MatForm(m.id) }
        } else s.hws.forEach { h ->
            ItemRow(null, h.name, tr("hk.${h.kind}"), priceOf(h.price, en), tr(perKey(h.kind))) { app.sheet = Sheet.HwForm(h.id) }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(18.dp)).border(2.dp, G.cobalt.copy(alpha = .45f), RoundedCornerShape(18.dp))
            .clickable(role = Role.Button) { app.sheet = if (tab == "m") Sheet.MatForm(null) else Sheet.HwForm(null) },
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
            MIcon("plus", G.cobalt2, 18.dp, 2.4f); Text(tr(if (tab == "m") "mt.addMat" else "mt.addHw"), style = ui(15f, 700, G.cobalt2))
        }
    }
}

@Composable
private fun matSub(m: Mat): String = when (m.kind) {
    "band" -> tr("mt.bandK") + " · " + tenths(m.t, LocalLang.current == Lang.EN) + " mm"
    "back" -> tr("mt.backK") + " · ${m.l} × ${m.w}"
    "worktop" -> tr("mt.wtK") + " · ${m.t} mm · ${m.l} × ${m.w}"
    "splash" -> tr("mt.splashK") + " · ${m.t} mm · ${m.l} × ${m.w}"
    else -> tr("mt.board") + " · ${m.t} mm · ${m.l} × ${m.w}" + if (m.grain) " · ↕" else ""
}

@Composable
private fun unitOf(m: Mat) = tr(if (m.kind == "band" || m.kind == "worktop" || m.kind == "splash") "mt.perM" else "mt.perSheet")

@Composable
private fun priceOf(p: String, en: Boolean) = p.toBigIntegerOrNull()?.let { moneyStr(it, 0, en) } ?: tr("mt.noPrice")

@Composable
private fun ItemRow(swatch: Color?, name: String, sub: String, price: String, unit: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(16.dp), fill = G.glass(.55f)).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (swatch != null) Box(Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(swatch).border(1.dp, G.ink.copy(alpha = .18f), RoundedCornerShape(8.dp)))
        else Box(Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(G.ink.copy(alpha = .07f)), contentAlignment = Alignment.Center) { MIcon("sliders", G.ink2, 16.dp, 2f) }
        Column(Modifier.weight(1f)) {
            Text(name, style = ui(14f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.End) { Text(price, style = num(14f, 800)); Text(unit, style = ui(11f, 400, G.ink2)) }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun WorkshopSheet(s: Sheet): Boolean = when (s) {
    is Sheet.WsField -> { FieldSheet(s.key); true }
    is Sheet.MatForm -> { MatSheet(s.id); true }
    is Sheet.HwForm -> { HwSheet(s.id); true }
    else -> false
}

/** Sizes that keep the sheet layout working: a board of 300 to 5000 mm, a saw cut under 10 mm, a trim under 100 mm. */
private fun mmRange(key: String) = when (key) {
    "sheetL", "sheetW" -> 300..5000
    "kerf" -> 0..10
    "trim" -> 0..100
    "legH" -> 0..300
    else -> 0..10000
}

/** A typed workshop value: digits, and for tenths of a mm one decimal; null when it is not a sensible number. */
private fun parseField(kind: WKind, text: String, key: String = ""): String? {
    val t = text.replace(" ", "").replace(',', '.')
    return when (kind) {
        WKind.MM10 -> t.toDoubleOrNull()?.takeIf { it in 0.0..50.0 }?.let { Math.round(it * 10).toInt().toString() }
        WKind.MM -> t.toIntOrNull()?.takeIf { it in mmRange(key) }?.toString()
        // a prepayment is part of the price; the markup may be more than the cost
        WKind.PCT -> t.toIntOrNull()?.takeIf { it in (if (key == "prepay") 0..100 else 0..500) }?.toString()
        WKind.MONEY -> t.takeIf { it.isNotEmpty() && it.all(Char::isDigit) }?.toBigInteger()?.toString()
    }
}

@Composable
private fun FieldSheet(key: String) {
    val app = LocalApp.current
    val s = app.settings
    val f = FIELDS.first { it.key == key }
    val en = LocalLang.current == Lang.EN
    val start = f.get(s.workshop).let { if (f.kind == WKind.MM10) tenths(it.toInt(), en) else it }
    var v by rememberSaveable { mutableStateOf(start) }
    val parsed = parseField(f.kind, v, f.key)
    val focus = remember { androidx.compose.ui.focus.FocusRequester() }
    fun save() { if (parsed == null) return; s.setWorkshopRules(f.set(s.workshop, parsed)); app.sheet = null; app.say("wk.saved") }
    GlassSheet(tr(f.label), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save, enabled = parsed != null) }) {
        GField(tr(f.label), v, { v = it }, "0", error = tr("wk.bad"), showError = parsed == null && v.isNotEmpty(), number = f.kind != WKind.MM10, money = f.kind == WKind.MONEY,
            labelRight = when (f.kind) { WKind.MM, WKind.MM10 -> tr("u.mm"); WKind.PCT -> "%"; WKind.MONEY -> curSuffix(s.currency, LocalLang.current) },
            imeAction = ImeAction.Done, onIme = ::save, focusRequester = focus)
    }
    // one value to change: the keyboard opens with the sheet
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(320); runCatching { focus.requestFocus() } }
}

private val SWATCHES = listOf("#F5F5F2", "#FFFFFF", "#CDBFAE", "#E8E4DC", "#B08D6E", "#7A5A40", "#4B4F58", "#1E293B")

@Composable
private fun MatSheet(id: String?) {
    val app = LocalApp.current
    val s = app.settings
    val edit = id?.let { x -> s.mats.firstOrNull { it.id == x } }
    var name by rememberSaveable { mutableStateOf(edit?.name ?: "") }
    var kind by rememberSaveable { mutableStateOf(edit?.kind ?: "board") }
    var t by rememberSaveable { mutableStateOf((edit?.t ?: 16).toString()) }
    var l by rememberSaveable { mutableStateOf((edit?.l ?: 2800).toString()) }
    var w by rememberSaveable { mutableStateOf((edit?.w ?: 2070).toString()) }
    var price by rememberSaveable { mutableStateOf(edit?.price ?: "") }
    var grain by rememberSaveable { mutableStateOf(edit?.grain ?: false) }
    var rgb by rememberSaveable { mutableStateOf(edit?.rgb ?: "#F5F5F2") }
    val band = kind == "band"
    val ti = t.toIntOrNull(); val li = l.toIntOrNull(); val wi = w.toIntOrNull()
    val ok = name.isNotBlank() && ti != null && ti > 0 && (band || (li != null && li in 300..6000 && wi != null && wi in 300..3000)) &&
        (price.isEmpty() || price.replace(" ", "").all(Char::isDigit))
    fun save() {
        if (!ok) return
        val m = Mat(edit?.id ?: uid(), kind, name.trim(), ti!!, if (band) 0 else li!!, if (band) 0 else wi!!, price.replace(" ", ""), grain && kind == "board", rgb, edit?.preset ?: false)
        s.setMatList(if (edit != null) s.mats.map { if (it.id == m.id) m else it } else s.mats + m)
        app.sheet = null; app.say("wk.saved")
    }
    GlassSheet(if (edit != null) edit.name else tr("mt.addMat"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (edit != null && !edit.preset) GBtn(tr("common.delete"), { s.setMatList(s.mats.filter { it.id != edit.id }); app.sheet = null }, Btn.DANGER, icon = "trash", height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = ok, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
        }
    }) {
        GField(tr("mt.name"), name, { name = it }, "LDSP 16 · …")
        if (edit == null) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("mt.kind"), style = ui(15f, 700))
            Seg(listOf("board" to tr("mt.board"), "back" to tr("mt.backK")), kind) { kind = it }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr("mt.t"), t, { t = it.filter(Char::isDigit) }, "16", number = true, labelRight = if (band) "0,1 " + tr("u.mm") else tr("u.mm"), modifier = Modifier.weight(1f))
            GField(tr("mt.price"), price, { price = it.filter { c -> c.isDigit() } }, "0", number = true, money = true,
                labelRight = tr(if (band || kind == "worktop" || kind == "splash") "mt.perM" else "mt.perSheet"), modifier = Modifier.weight(1f))
        }
        if (!band) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr("mt.l"), l, { l = it.filter(Char::isDigit) }, "2800", number = true, labelRight = tr("u.mm"), modifier = Modifier.weight(1f))
            GField(tr("mt.w"), w, { w = it.filter(Char::isDigit) }, "2070", number = true, labelRight = tr("u.mm"), modifier = Modifier.weight(1f))
        }
        if (kind == "board") Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).switchState(grain).clickable(role = Role.Switch) { grain = !grain }, verticalAlignment = Alignment.CenterVertically) {
            Text(tr("mt.grain"), style = ui(14.5f, 500), modifier = Modifier.weight(1f)); GSwitch(grain)
        }
        if (!band) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("mt.color"), style = ui(15f, 700))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SWATCHES.forEach { c ->
                    Box(Modifier.size(32.dp).clip(CircleShape).background(Color(android.graphics.Color.parseColor(c)))
                        .border(if (c == rgb) 3.dp else 1.dp, if (c == rgb) G.cobalt else G.ink.copy(alpha = .2f), CircleShape)
                        .clickable(role = Role.RadioButton) { rgb = c })
                }
            }
        }
        if (edit?.preset == true) Text(tr("mt.presetNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

private val HW_KINDS = listOf("hingeSoft", "hinge", "runner", "handle", "leg", "pin", "rail", "railEnd", "confirmat", "hanger", "lift",
    "slideTrack", "slideV", "slideH", "slideRoller", "mirror", "glass",
    "wtJoint", "wtMitre", "wtCut", "wtEnd", "plinthK", "plinthCorner", "cornice", "led", "ledPsu")

/** "so‘m / m", "so‘m / m²" or "so‘m / dona" for a hardware kind. */
private fun perKey(kind: String) = when (uz.metrx.app.furniture.hwUnit(kind)) { "m" -> "mt.perM"; "m2" -> "mt.perM2"; else -> "mt.perPc" }

@Composable
private fun HwSheet(id: String?) {
    val app = LocalApp.current
    val s = app.settings
    val edit = id?.let { x -> s.hws.firstOrNull { it.id == x } }
    var name by rememberSaveable { mutableStateOf(edit?.name ?: "") }
    var kind by rememberSaveable { mutableStateOf(edit?.kind ?: "handle") }
    var price by rememberSaveable { mutableStateOf(edit?.price ?: "") }
    val ok = name.isNotBlank()
    fun save() {
        if (!ok) return
        val h = Hw(edit?.id ?: uid(), kind, name.trim(), price, edit?.preset ?: false)
        // the cost counts the last item of each kind: a new one of a kind takes over from the preset
        s.setHwList(if (edit != null) s.hws.map { if (it.id == h.id) h else it } else s.hws + h)
        app.sheet = null; app.say("wk.saved")
    }
    GlassSheet(if (edit != null) edit.name else tr("mt.addHw"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (edit != null && !edit.preset) GBtn(tr("common.delete"), { s.setHwList(s.hws.filter { it.id != edit.id }); app.sheet = null }, Btn.DANGER, icon = "trash", height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = ok, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
        }
    }) {
        GField(tr("mt.name"), name, { name = it }, "GTV, Blum, Boyard…")
        GField(tr("mt.price"), price, { price = it.filter(Char::isDigit) }, "0", number = true, money = true,
            labelRight = tr(perKey(kind)), imeAction = ImeAction.Done)
        if (edit == null) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("mt.hwKind"), style = ui(15f, 700))
            HW_KINDS.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEach { k ->
                        val on = k == kind
                        Text(tr("hk.$k"), style = ui(13f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), maxLines = 1,
                            modifier = Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
                                .border(1.dp, if (on) G.cobalt else G.idleRim, RoundedCornerShape(12.dp)).clickable(role = Role.RadioButton) { kind = k }.padding(horizontal = 12.dp, vertical = 12.dp))
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
        if (edit?.preset == true) Text(tr("mt.presetNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

