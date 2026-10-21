package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.CostLine
import uz.metrx.app.furniture.CutRow
import uz.metrx.app.furniture.FPrice
import uz.metrx.app.furniture.costOf
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.furniture.runMm
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigInteger
import kotlin.math.max
import kotlin.math.min

/*
 * Furniture orders, Stage 1a part 7 (furniture plan sections 6.4–6.7 and 10; design canvas screens 14–17): the Narx tab
 * (cost, how the customer price is worked out, profit, lead time), the parts and sheet layout screen, and the way to
 * the two documents. Everything here is the maker's only.
 */

private val DARK = Color(0xFF0E1C36)

@Composable
private fun money(p: Project, v: BigInteger): String = moneyStr(v, p.precision, LocalLang.current == Lang.EN)

private fun qtyStr(q: Double, en: Boolean): String =
    if (q == Math.floor(q)) "${q.toLong()}" else String.format(java.util.Locale.ROOT, "%.1f", q).let { if (en) it else it.replace('.', ',') }

/** "LDSP 16 · Oq · 9 list × 620 000", "Kesish · 18 list × 45 000", "O‘rnatish". */
@Composable
private fun lineText(p: Project, l: CostLine): String {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val name = when (l.group) {
        "mat" -> app.settings.mats.firstOrNull { it.id == l.key }?.name ?: l.key
        "hw" -> app.settings.hws.firstOrNull { it.id == l.key }?.name ?: tr("hk.${l.key}")
        else -> tr(l.key)
    }
    if (l.unit == "order") return name
    val unit = tr("fu.${l.unit}")
    return "$name · ${qtyStr(l.qty, en)} $unit × " + if (l.missing) tr("mt.noPrice") else money(p, l.price)
}

/** The Narx tab of a furniture order. */
@Composable
fun FPriceTab(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    if (fs.isEmpty()) {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 14.dp).fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(56.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("coin", G.cobalt, 26.dp, 2f) }
            Text(tr("fp.empty"), style = ui(15f, 500, G.ink2, 1.45f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        return
    }
    val fp = p.fprice
    val pr = remember(p.furniture, fp, s.workshop, s.mats, s.hws) { priceOf(fs, fp, s.workshop, s.mats, s.hws) }
    val cost = pr.cost
    val cur = curSuffix(p.currency, lang)
    fun setFp(f: (FPrice) -> FPrice) { app.store.update(p.id) { it.copy(fprice = f(it.fprice)) } }
    var open by rememberSaveable { mutableStateOf("") }   // the cost groups start folded
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // the customer price and the profit
        val neg = pr.profit.signum() < 0
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(DARK).padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(tr("fp.price"), style = ui(12.5f, 400, Color(0xFFB7C3D9)))
            Text(money(p, pr.price) + " " + cur, style = ui(26f, 800, Color.White).copy(fontFamily = PlexCond), maxLines = 1)
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fw.profit"), style = ui(13f, 400, Color(0xFFB7C3D9)), modifier = Modifier.weight(1f))
                val pc = pr.profitPct10
                // −0,5 % keeps its minus: the whole part alone would say 0
                Text(money(p, pr.profit) + " · ${if (pc < 0) "−" else ""}${kotlin.math.abs(pc) / 10}${if (lang == Lang.EN) "." else ","}${kotlin.math.abs(pc) % 10} %",
                    style = ui(15f, 700, if (neg) Color(0xFFFCA5A5) else Color(0xFF86EFAC)).copy(fontFamily = PlexCond))
            }
            if (neg) Text(tr("fp.loss"), style = ui(12.5f, 600, Color(0xFFFCA5A5)))
        }
        // how the customer price is worked out
        Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(tr("fp.how"), style = ui(15f, 800))
            Seg(listOf("margin" to tr("fpm.margin"), "run" to tr("fpm.run"), "fixed" to tr("fpm.fixed")), fp.mode) { m -> setFp { it.copy(mode = m) } }
            val pct = fp.pct ?: s.workshop.margin
            when (fp.mode) {
                "fixed" -> {
                    PriceRow(tr("fp.fixed"), if (fp.fixed.isBlank()) "—" else money(p, fp.fixed.toBigIntegerOrNull() ?: BigInteger.ZERO) + " " + cur) { app.sheet = Sheet.FPriceField(p.id, "fixed") }
                    Text(tr("fp.howFixed"), style = ui(12.5f, 400, G.ink2, 1.4f))
                }
                else -> {
                    Stepper(tr("fp.margin"), pct, 0, 300) { v -> setFp { it.copy(pct = v) } }
                    if (fp.mode == "run") {
                        PriceRow(tr("fp.rRun"), money(p, fp.rRun.toBigIntegerOrNull() ?: BigInteger.ZERO) + " " + cur) { app.sheet = Sheet.FPriceField(p.id, "rRun") }
                        PriceRow(tr("fp.rTall"), if (fp.rTall.isBlank()) "—" else money(p, fp.rTall.toBigIntegerOrNull() ?: BigInteger.ZERO) + " " + cur) { app.sheet = Sheet.FPriceField(p.id, "rTall") }
                    }
                    val en = lang == Lang.EN
                    pr.lines.forEach { ln ->
                        val f = fs.firstOrNull { it.id == ln.key }
                        val how = when {
                            ln.key == "deliver" -> tr("fd.deliver") + ": " + tr("fp.plusPct", "p" to pct)
                            f != null && fp.mode == "run" && f.kind == "kitchen" -> {
                                val v = (runMm(f) + 50) / 100
                                dn(f.name, lang) + ": " + "${v / 10}${if (en) "." else ","}${v % 10} " + tr("kt.pm") + " × " + money(p, fp.rRun.toBigIntegerOrNull() ?: BigInteger.ZERO)
                            }
                            f != null -> dn(f.name, lang) + ": " + tr("fp.plusPct", "p" to pct)
                            else -> ln.key
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(how, style = ui(12.5f, 400, G.ink2, 1.35f), modifier = Modifier.weight(1f))
                            Text(money(p, ln.amount), style = num(13f, 600, G.ink2))
                        }
                    }
                }
            }
        }
        // the documents: the customer's PDF first, then the workshop's pack and the parts with their sheet layout
        GBtn(tr("fd.btn"), { app.push(Route.Report(p.id)) }, icon = "share", height = 52.dp, corner = 16.dp, fontSize = 15.5f)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn(tr("fw.btn"), { app.push(Route.FPack(p.id)) }, Btn.SECONDARY, icon = "doc", height = 50.dp, corner = 16.dp, fontSize = 14.5f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("fc.title"), { app.push(Route.FCut(p.id)) }, Btn.SECONDARY, icon = "board", height = 50.dp, corner = 16.dp, fontSize = 14.5f, modifier = Modifier.weight(1f), maxLines = 2)
        }
        Text(tr("fp.docsNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
        PriceRow(tr("fp.days"), tr("fd.days", "d" to fp.days, "i" to fp.inst)) { app.sheet = Sheet.FPriceField(p.id, "days") }
        // the cost, by group
        Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("fp.cost"), style = ui(12.5f, 600, G.ink2))
            Text(money(p, cost.total) + " " + cur, style = num(26f, 800))
            Text(fs.joinToString(" + ") { dn(it.name, lang) } + " · " + tr("fp.onlyYou"), style = ui(12.5f, 400, G.ink2), maxLines = 2)
            listOf("mat" to "fw.g.mat", "hw" to "fw.g.hw", "lab" to "fw.g.lab").forEach { (g, k) ->
                Hairline()
                val on = open == g
                Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).clickable(role = Role.Button) { open = if (on) "" else g }, verticalAlignment = Alignment.CenterVertically) {
                    Text((if (on) "▾ " else "▸ ") + tr(k), style = ui(15f, 700), modifier = Modifier.weight(1f))
                    Text(money(p, cost.sum(g)), style = num(15f, 700))
                }
                if (on) cost.lines.filter { it.group == g }.forEach { l ->
                    Row(Modifier.fillMaxWidth().padding(start = 14.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(lineText(p, l), style = ui(13f, 400, if (l.missing) G.amberInk else G.ink2, 1.35f), modifier = Modifier.weight(1f))
                        Text(money(p, l.amount), style = num(13.5f, 600))
                    }
                }
            }
            if (cost.missing > 0) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).clickable(role = Role.Button) { app.push(Route.Materials) }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon("alert", G.amberInk, 18.dp, 2f)
                Text(tr("kt.noPrice", "n" to cost.missing), style = ui(13.5f, 500, G.amberInk), modifier = Modifier.weight(1f))
                Text(tr("fp.setPrices"), style = ui(13.5f, 700, G.amberInk))
            }
        }
    }
}

@Composable
private fun PriceRow(label: String, value: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(14.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(14.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = ui(14.5f, 500), modifier = Modifier.weight(1f))
        Text(value, style = num(15f, 700), maxLines = 1); Box(Modifier.width(6.dp)); MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun PriceSheet(s: Sheet): Boolean = when (s) {
    is Sheet.FPriceField -> { PriceFieldSheet(s); true }
    else -> false
}

@Composable
private fun PriceFieldSheet(s: Sheet.FPriceField) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val fp = p.fprice
    val money = s.key != "days"
    var a by rememberSaveable { mutableStateOf(when (s.key) { "fixed" -> fp.fixed; "rRun" -> fp.rRun; "rTall" -> fp.rTall; else -> fp.days.toString() }) }
    var b by rememberSaveable { mutableStateOf(fp.inst.toString()) }
    val ai = a.replace(" ", "")
    val ok = if (money) ai.isEmpty() || ai.all(Char::isDigit) else (ai.toIntOrNull() ?: -1) in 1..365 && (b.toIntOrNull() ?: -1) in 0..60
    fun save() {
        if (!ok) return
        app.store.update(p.id) { pr -> pr.copy(fprice = when (s.key) {
            "fixed" -> pr.fprice.copy(fixed = ai); "rRun" -> pr.fprice.copy(rRun = ai); "rTall" -> pr.fprice.copy(rTall = ai)
            else -> pr.fprice.copy(days = ai.toInt(), inst = b.toInt())
        }) }
        app.sheet = null
    }
    val title = when (s.key) { "fixed" -> tr("fp.fixed"); "rRun" -> tr("fp.rRun"); "rTall" -> tr("fp.rTall"); else -> tr("fp.days") }
    GlassSheet(title, { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save, enabled = ok) }) {
        if (money) {
            val focus = remember { androidx.compose.ui.focus.FocusRequester() }
            GField(title, a, { a = it.filter { c -> c.isDigit() } }, "0", number = true, money = true, labelRight = curSuffix(p.currency, lang), imeAction = ImeAction.Done, onIme = ::save, focusRequester = focus)
            // one value to change: the keyboard opens with the sheet
            LaunchedEffect(Unit) { kotlinx.coroutines.delay(320); runCatching { focus.requestFocus() } }
        }
        else {
            GField(tr("fp.daysMake"), a, { a = it.filter(Char::isDigit).take(3) }, "18", number = true, labelRight = tr("fp.wd"), error = tr("km.bad", "a" to 1, "b" to 365), showError = !ok && a.isNotEmpty())
            GField(tr("fp.daysInst"), b, { b = it.filter(Char::isDigit).take(2) }, "1", number = true, labelRight = tr("fp.wd"), imeAction = ImeAction.Done, onIme = ::save)
        }
        Text(tr(when (s.key) { "rRun" -> "fp.rRunNote"; "rTall" -> "fp.rTallNote"; "fixed" -> "fp.howFixed"; else -> "fp.daysNote" }), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/* ---------------- parts and sheet layout ---------------- */

/** Banding on a part's edges, drawn: a thick edge is a thick line, a thin one a thin line (design canvas screen 15). */
@Composable
private fun BandGlyph(r: CutRow) {
    Canvas(Modifier.size(34.dp, 20.dp)) {
        val pad = 3.dp.toPx(); val w = size.width - 2 * pad; val h = size.height - 2 * pad
        val b = r.p.bands
        drawRect(G.ink.copy(alpha = .08f), Offset(pad, pad), Size(w, h))
        fun edge(code: Int, a: Offset, c: Offset) {
            if (code == 0) drawLine(G.ink3.copy(alpha = .35f), a, c, 1f, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(3f, 3f)))
            else drawLine(G.ink, a, c, if (code == 2) 3.dp.toPx() else 1.2.dp.toPx())
        }
        edge(b.l1, Offset(pad, pad), Offset(pad + w, pad)); edge(b.l2, Offset(pad, pad + h), Offset(pad + w, pad + h))
        edge(b.s1, Offset(pad, pad), Offset(pad, pad + h)); edge(b.s2, Offset(pad + w, pad), Offset(pad + w, pad + h))
    }
}

@Composable
fun CutScreen(rt: Route.FCut) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val p = app.store.get(rt.pid) ?: return
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    val cost = remember(p.furniture, s.workshop, s.mats, s.hws) { costOf(fs, s.workshop, s.mats, s.hws) }
    var tab by rememberSaveable { mutableStateOf("l") }
    var mat by rememberSaveable { mutableStateOf(cost.layouts.firstOrNull()?.mat ?: "") }
    var sheet by rememberSaveable { mutableIntStateOf(0) }
    val lay = cost.layouts.firstOrNull { it.mat == mat } ?: cost.layouts.firstOrNull()
    val rowsAll = cost.rows
    val idx = rowsAll.withIndex().filter { it.value.mat == lay?.mat }
    val number = idx.mapIndexed { k, iv -> iv.index to k + 1 }.toMap()
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() })
            Column(Modifier.weight(1f)) {
                Text(tr("fc.title"), style = ui(19f, 800), maxLines = 1)
                Text(tr("fc.sub", "n" to rowsAll.sumOf { it.p.qty }, "s" to cost.layouts.sumOf { it.sheets.size }), style = ui(12f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (lay == null) { Text(tr("fp.empty"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.padding(24.dp)); return@Column }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Seg(listOf("l" to tr("fc.parts"), "s" to tr("fc.sheets")), tab) { tab = it }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                cost.layouts.forEach { l ->
                    val m = s.mats.firstOrNull { it.id == l.mat }
                    Chip((m?.name ?: l.mat) + " · ${l.sheets.size}", l.mat == lay.mat) { mat = l.mat; sheet = 0 }
                }
            }
            if (tab == "l") Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(Modifier.fillMaxWidth().padding(bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("№", style = ui(11.5f, 700, G.ink2), modifier = Modifier.width(24.dp))
                    Text(tr("fw.c.part"), style = ui(11.5f, 700, G.ink2), modifier = Modifier.weight(1f))
                    Text(tr("fw.c.size"), style = ui(11.5f, 700, G.ink2))
                    // narrow columns: the heading shrinks rather than being cut off ("Kromk") with a large system font
                    FitText(tr("fw.c.qty"), ui(11.5f, 700, G.ink2), Modifier.width(34.dp))
                    FitText(tr("fw.c.band"), ui(11.5f, 700, G.ink2), Modifier.width(52.dp))
                }
                idx.forEach { (i, r) ->
                    Hairline()
                    Row(Modifier.fillMaxWidth().heightIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("${number[i]}", style = num(13f, 700, G.ink2), modifier = Modifier.width(24.dp))
                        Column(Modifier.weight(1f)) {
                            Text(tr(r.p.key) + if (r.p.grain) " ↕" else "", style = ui(13.5f, 600), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (r.cutL != r.p.L || r.cutW != r.p.W) Text(tr("wk.cut", "v" to "${r.cutL} × ${r.cutW}"), style = ui(11.5f, 400, G.ink2))
                        }
                        Text("${r.p.L} × ${r.p.W}", style = num(13.5f, 700))
                        Text("× ${r.p.qty}", style = num(13f, 600, G.ink2), maxLines = 1, modifier = Modifier.width(34.dp))
                        Box(Modifier.width(52.dp)) { BandGlyph(r) }
                    }
                }
                Text(tr("fc.bandNote"), style = ui(12f, 400, G.ink2, 1.4f), modifier = Modifier.padding(top = 6.dp))
            } else {
                val n = lay.sheets.size
                val i = sheet.coerceIn(0, max(0, n - 1))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GlassIconButton("back", tr("rp2.prev"), { if (i > 0) sheet = i - 1 }, tint = if (i > 0) G.ink else G.ink3.copy(alpha = .4f))
                    Text(tr("fc.sheetN", "i" to i + 1, "n" to n, "l" to lay.sheetL, "w" to lay.sheetW), style = ui(14f, 700), modifier = Modifier.weight(1f), maxLines = 2)
                    Text(tr("fc.waste", "v" to (lay.waste * 100).toInt()), style = ui(12.5f, 600, G.ink2))
                    GlassIconButton("chev", tr("rp2.next"), { if (i < n - 1) sheet = i + 1 }, tint = if (i < n - 1) G.ink else G.ink3.copy(alpha = .4f))
                }
                lay.sheets.getOrNull(i)?.let { sp ->
                    val tm = rememberTextMeasurer()
                    val ws = s.workshop
                    Canvas(Modifier.fillMaxWidth().aspectRatio(lay.sheetL.toFloat() / lay.sheetW).clip(RoundedCornerShape(6.dp)).background(Color(0xFFF3F6FA)).border(1.dp, G.ink, RoundedCornerShape(6.dp))) {
                        val k = size.width / lay.sheetL; val tr0 = ws.trim * k
                        sp.placed.forEach { pl ->
                            val x = tr0 + pl.x * k; val y = tr0 + pl.y * k; val w = pl.w * k; val h = pl.h * k
                            drawRect(Color(0xFFDDE6F5), Offset(x, y), Size(w, h)); drawRect(Color(0xFF3E4A61), Offset(x, y), Size(w, h), style = Stroke(1f))
                            val fsz = min(13f, min(w, h) / density * .42f)
                            if (fsz >= 6f) {
                                val st = TextStyle(fontFamily = PlexCond, fontSize = fsz.sp, color = Color(0xFF0E1C36))
                                val lr = tm.measure("${number[pl.row] ?: "?"}", st)
                                if (lr.size.width < w && lr.size.height < h) drawText(lr, topLeft = Offset(x + (w - lr.size.width) / 2, y + (h - lr.size.height) / 2))
                            }
                        }
                    }
                }
                Text(tr("fw.sheetNote", "l" to lay.sheetL, "w" to lay.sheetW, "k" to s.workshop.kerf, "t" to s.workshop.trim), style = ui(12.5f, 400, G.ink2, 1.4f))
                if (lay.unplaced.isNotEmpty()) Text(tr("fw.unplaced", "m" to (s.mats.firstOrNull { it.id == lay.mat }?.name ?: lay.mat), "n" to lay.unplaced.size), style = ui(13f, 600, G.err, 1.4f))
            }
            GBtn(tr("fw.btn"), { app.push(Route.FPack(p.id)) }, Btn.SECONDARY, icon = "doc", height = 48.dp, corner = 16.dp, fontSize = 15f)
        }
    }
}

/** One line of text that shrinks (down to 8 sp) to fit its width instead of being cut off. */
@Composable
internal fun FitText(s: String, style: androidx.compose.ui.text.TextStyle, modifier: Modifier = Modifier) =
    androidx.compose.foundation.text.BasicText(s, modifier, style = style, maxLines = 1,
        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 8.sp, maxFontSize = style.fontSize, stepSize = .5.sp))
