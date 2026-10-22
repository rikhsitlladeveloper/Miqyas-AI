package uz.metrx.app.ui.projects

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import uz.metrx.app.core.Dec
import uz.metrx.app.core.Lang
import uz.metrx.app.core.canonOf
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.fmtNumStr
import uz.metrx.app.core.lineTotal
import uz.metrx.app.core.moneyStr
import uz.metrx.app.core.parseDec
import uz.metrx.app.core.totals
import uz.metrx.app.core.value
import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import uz.metrx.app.data.dn
import uz.metrx.app.data.uid
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.editor.unitName
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigDecimal
import java.math.BigInteger
import java.math.RoundingMode

/*
 * The Smeta tab (prototype glass.js stages 4–6): area tiles, the materials and labour cards, an empty state with quick
 * adds, the floating total, and the row sheet with suggestions, units, "take from the rooms", +10 % spare and drafts.
 */

private const val P_RCPT = "M6 3h12v18l-3-2-3 2-3-2-3 2z M9 8h6 M9 12h6 M9 16h3"
private const val P_PLAN = "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M3 12h9V3 M12 12v9"
private const val P_FLOOR = "M3 9l9-5 9 5-9 5z M3 15l9 5 9-5"
private val AMBER get() = if (Theme.dark) G.amberInk else Color(0xFF9A5800)
private val COB_DARK get() = if (Theme.dark) G.cobalt2 else Color(0xFF1E36B0)
private val OK_INK get() = if (Theme.dark) G.green else Color(0xFF15803D)
private val RULE get() = G.rim

/** Material suggestions' units (prototype GS_MAT_UNITS) and the unit chips (GS_UNITS). */
private val SUG_UNITS = listOf("@u.m2", "@u.l", "@u.bag", "@u.l", "@u.m2", "@u.m2")
private val UNITS = listOf("u.pcs", "u.m2", "u.m", "u.kg", "u.l", "u.bag", "u.can", "u.set")

/** The project's net wall and floor areas in mm², from the rooms that have them (prototype gsAreas). */
data class PjAreas(val w: Long, val f: Long, val nw: Int, val nf: Int)

fun pjAreas(p: Project, snap: Boolean): PjAreas {
    var w = 0L; var f = 0L; var nw = 0; var nf = 0
    p.rooms.forEach { r -> areas(r, snap)?.let { a -> f += a.floor; nf++; a.net?.let { w += it; nw++ } } }
    return PjAreas(w, f, nw, nf)
}

fun money(v: BigInteger, p: Project, l: Lang, withCur: Boolean = false) = moneyStr(v, p.precision, l == Lang.EN) + if (withCur) " " + curSuffix(p.currency, l) else ""

/** Shared glass surface of the Smeta cards. */
private fun Modifier.gsCard(r: androidx.compose.ui.unit.Dp, shadow: androidx.compose.ui.unit.Dp = 28.dp, a: Float = .12f, dy: androidx.compose.ui.unit.Dp = 12.dp): Modifier {
    val shape = RoundedCornerShape(r)
    return this.dropShadow(shape, Shadow(shadow, G.shade.copy(alpha = a), offset = DpOffset(0.dp, dy))).clip(shape)
        .background(G.glass(.45f)).topHighlight(.95f, 1.5.dp).border(.67.dp, RULE, shape)
}

@Composable
fun EstimateTab(p: Project, lang: Lang) {
    val app = LocalApp.current
    val en = lang == Lang.EN
    val mats = p.estimate.materials; val labs = p.estimate.labor
    val tt = totals(p)
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Stats(p, lang)
        // after a quote: is the draft still the same as the last one issued? (prototype es.same / es.changed)
        p.quotes.lastOrNull()?.let { q ->
            val same = uz.metrx.app.report.fingerprint(uz.metrx.app.report.snapshotOf(p, app.settings)) == q.fp
            QuoteBanner(same, tr(if (same) "es.same" else "es.changed", "n" to q.no))
        }
        if (p.isTiler) uz.metrx.app.ui.tiles.TilesCard(p) else if (uz.metrx.app.trades.isTrade(p.industry)) uz.metrx.app.ui.projects.TradeCard(p)
        if (mats.isEmpty() && labs.isEmpty()) { EmptyEstimate(p); return@Column }
        RowsCard(tr("es.mat"), mats.size, money(tt.m, p, lang), "gs.addMat", app.settings.rowDrafts.containsKey(p.id + "|mat|new"), { app.sheet = Sheet.Row(p.id, "mat") }) {
            if (mats.isEmpty()) None(tr("gs.noMat"))
            mats.forEach { m ->
                val bad = m.qty.isBlank() || m.price.isBlank()
                LineRow(dn(m.name, lang).ifEmpty { "—" },
                    if (bad) tr("gs.miss") else "${fmtNumStr(m.qty, en)} ${dn(m.unit, lang)} × ${money(parseDec(m.price, p.precision).value() ?: BigInteger.ZERO, p, lang)}",
                    bad, if (bad) "—" else money(lineTotal(m.qty, m.price, p.precision), p, lang)) { app.sheet = Sheet.Row(p.id, "mat", m.id) }
            }
        }
        RowsCard(tr("es.lab"), labs.size, money(tt.l, p, lang), "gs.addLab", app.settings.rowDrafts.containsKey(p.id + "|lab|new"), { app.sheet = Sheet.Row(p.id, "lab") }) {
            if (labs.isEmpty()) None(tr("gs.noLab"))
            labs.forEach { l ->
                val bad = l.amount.isBlank()
                LineRow(dn(l.name, lang).ifEmpty { "—" }, tr(if (bad) "gs.missL" else "es.lump"), bad,
                    if (bad) "—" else money(parseDec(l.amount, p.precision).value() ?: BigInteger.ZERO, p, lang)) { app.sheet = Sheet.Row(p.id, "lab", l.id) }
            }
        }
        Row(Modifier.padding(horizontal = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("info", G.ink2, 18.dp, 2f)
            Text(tr("es.note"), style = ui(13f, 400, G.ink2, 1.45f), modifier = Modifier.weight(1f))
        }
    }
}

/** Whether the draft matches the last issued quote. */
@Composable
fun QuoteBanner(same: Boolean, text: String) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().clip(shape).background(if (same) Color(0x1F16A34A) else G.amberWash).border(1.dp, if (same) Color(0x3316A34A) else Color(0x33EA8C00), shape)
        .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        MIcon(if (same) "check" else "info", if (same) OK_INK else AMBER, 18.dp, 2.2f)
        Text(text, style = ui(13.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f))
    }
}

/** Net walls, floor (both open the areas by room) and the currency (prototype gsStats). */
@Composable
private fun Stats(p: Project, lang: Lang) {
    val app = LocalApp.current
    val a = pjAreas(p, app.settings.angleSnap); val en = lang == Lang.EN
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        StatTile(Modifier.weight(1f), { MIcon("walls", G.cobalt, 16.dp, 2f) }, tr("gs.wallNet"), if (a.nw > 0) fmtArea(a.w, en) else null) { app.sheet = Sheet.Areas(p.id) }
        StatTile(Modifier.weight(1f), { PathIcon(P_FLOOR, G.cobalt, 16.dp, 2f) }, tr("gs.floor"), if (a.nf > 0) fmtArea(a.f, en) else null) { app.sheet = Sheet.Areas(p.id) }
        Column(Modifier.fillMaxHeight().gsCard(20.dp, 20.dp, .08f, 8.dp).padding(start = 12.dp, end = 14.dp, top = 11.dp, bottom = 10.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Text(tr("gs.cur"), style = ui(12f, 600, G.ink2))
            Text(p.currency, style = ui(18f, 800), modifier = Modifier.padding(top = 6.dp))
        }
    }
}

@Composable
private fun StatTile(modifier: Modifier, icon: @Composable () -> Unit, label: String, value: String?, onClick: () -> Unit) {
    Box(modifier.fillMaxHeight().gsCard(20.dp, 20.dp, .08f, 8.dp).clickable(role = Role.Button, onClick = onClick).padding(start = 12.dp, end = 12.dp, top = 11.dp, bottom = 10.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.padding(end = 14.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                icon(); Text(label, style = ui(12f, 600, G.ink2, 1.4f))
            }
            // a long area gets smaller and gives way first, so "m²" always shows
            Row(verticalAlignment = Alignment.Bottom) {
                Text(value ?: "—", style = ui(if ((value?.length ?: 0) > 6) 15f else 18f, 800), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false))
                if (value != null) Text(tr("u.m2"), style = ui(12f, 600, G.ink2), maxLines = 1, softWrap = false, modifier = Modifier.padding(start = 3.dp, bottom = 3.dp))
            }
        }
        MIcon("chev", Color(0xFF94A3B8), 14.dp, 2.2f, Modifier.align(Alignment.TopEnd))
    }
}

/** No rows yet: a card with Material / Labour and the quick adds (prototype .gs-empty, .gs-quick). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EmptyEstimate(p: Project) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().gsCard(28.dp).padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(64.dp).clip(RoundedCornerShape(22.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { PathIcon(P_RCPT, G.cobalt, 30.dp, 1.8f) }
        Text(tr("gs.empty"), style = ui(20f, 800, G.ink, 1.4f), textAlign = TextAlign.Center, modifier = Modifier.padding(top = 14.dp))
        Text(tr("gs.emptyB"), style = ui(14f, 400, G.ink2, 1.45f), textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
        Row(Modifier.padding(top = 18.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn(tr("gs.mat"), { app.sheet = Sheet.Row(p.id, "mat") }, icon = "plus", modifier = Modifier.weight(1f), height = 52.dp, corner = 26.dp, fontSize = 15f)
            GBtn(tr("gs.lab"), { app.sheet = Sheet.Row(p.id, "lab") }, Btn.SECONDARY, icon = "plus", modifier = Modifier.weight(1f), height = 52.dp, corner = 26.dp, fontSize = 15f)
        }
    }
    Text(tr("gs.quick"), style = ui(13f, 700, G.ink2), modifier = Modifier.padding(start = 4.dp, top = 6.dp))
    val sm = tr("gs.sMat").split('|'); val sl = tr("gs.sLab").split('|')
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        sm.take(4).forEachIndexed { i, n -> Quick(n) { app.sheet = Sheet.Row(p.id, "mat", name = n, unit = SUG_UNITS[i]) } }
        sl.take(2).forEach { n -> Quick(n) { app.sheet = Sheet.Row(p.id, "lab", name = n) } }
    }
}

@Composable
private fun Quick(n: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Row(Modifier.height(40.dp).clip(shape).background(G.glass(.5f)).border(1.dp, G.rim, shape).clickable(role = Role.Button, onClick = onClick)
        .padding(start = 10.dp, end = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        MIcon("plus", G.cobalt, 14.dp, 2.4f); Text(n, style = ui(14f, 600), maxLines = 1)
    }
}

@Composable
private fun RowsCard(title: String, n: Int, total: String, addKey: String, draft: Boolean, onAdd: () -> Unit, rows: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().gsCard(26.dp)) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = ui(16f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, false))
            Text("· $n", style = ui(16f, 600, G.ink2))
            Spacer(Modifier.weight(1f))
            Text(total, style = ui(14f, 800), maxLines = 1)
        }
        rows()
        Row(Modifier.fillMaxWidth().topRule().height(48.dp).background(G.cobalt.copy(alpha = .06f)).clickable(role = Role.Button, onClick = onAdd).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("plus", G.cobalt2, 18.dp, 2.2f)
            Text(tr(addKey), style = ui(15f, 700, G.cobalt2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, false))
            if (draft) Text(tr("gs.dTag"), style = ui(11f, 700, AMBER), modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(G.amberWash).padding(horizontal = 7.dp, vertical = 2.dp))
        }
    }
}

private fun Modifier.topRule() = drawBehind { drawLine(RULE, Offset(0f, 0f), Offset(size.width, 0f), .67.dp.toPx()) }

@Composable
private fun None(text: String) {
    Text(text, style = ui(13.5f, 400, G.ink2), modifier = Modifier.fillMaxWidth().topRule().padding(horizontal = 16.dp, vertical = 14.dp))
}

@Composable
private fun LineRow(name: String, sub: String, bad: Boolean, sum: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().topRule().heightIn(min = 60.dp).clickable(role = Role.Button, onClick = onClick).padding(start = 16.dp, end = 12.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f)) {
            Text(name, style = ui(15f, 700), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(sub, style = ui(12f, if (bad) 600 else 400, if (bad) AMBER else G.ink2, 1.4f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Text(sum, style = ui(15f, 800), maxLines = 1)
        MIcon("chev", G.ink2, 18.dp, 2.2f)
    }
}

/** The floating total over the tab bar (prototype .footer.gs-tot); none while the estimate is empty. */
@Composable
fun EstimateTotal(p: Project, lang: Lang) {
    val app = LocalApp.current
    val tt = totals(p)
    val shape = RoundedCornerShape(30.dp)
    Column(
        Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp).fillMaxWidth()
            .dropShadow(shape, Shadow(30.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, (-10).dp)))
            .clip(shape).glassBlur(LocalHaze.current, G.sheet(.6f), 28.dp).topHighlight(.95f, 1.5.dp).border(.67.dp, G.rim, shape)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(Modifier.padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f)) {
                Text(tr("es.grand"), style = ui(13f, 400, G.ink2))
                Text(tr("gs.split", "m" to money(tt.m, p, lang), "l" to money(tt.l, p, lang)), style = ui(12f, 400, G.ink2, 1.35f))
            }
            Row(verticalAlignment = Alignment.Bottom) {
                Text(money(tt.g, p, lang), style = ui(24f, 800), maxLines = 1)
                Text(" " + curSuffix(p.currency, lang), style = ui(14f, 700), modifier = Modifier.padding(bottom = 4.dp))
            }
        }
        GBtn(tr("es.preview"), { app.push(uz.metrx.app.ui.Route.Report(p.id)) }, icon = "doc", height = 54.dp, corner = 27.dp, fontSize = 16f)
    }
}

/* ---------------- sheets ---------------- */

/** The rooms' floor, perimeter and net walls, for reference only (prototype SHEETS.areas). */
@Composable
fun AreasSheet(s: Sheet.Areas) {
    val app = LocalApp.current
    val lang = LocalLang.current; val en = lang == Lang.EN
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val snap = app.settings.angleSnap
    GlassSheet(tr("es.areas"), { app.sheet = null }, footer = { GBtn(tr("common.close"), { app.sheet = null }, Btn.SECONDARY) }) {
        if (p.rooms.isEmpty()) Text(tr("pr.emptyTitle"), style = ui(14f, 400, G.ink2))
        p.rooms.forEach { r ->
            val a = areas(r, snap)
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(dn(r.name, lang), style = ui(15f, 700))
                if (a == null) Text(tr("rp.missing"), style = ui(13.5f, 400, G.ink2))
                else Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp)) {
                    Kv2(tr("rp.floorArea"), fmtArea(a.floor, en) + " " + tr("u.m2"))
                    Hairline(); Kv2(tr("rp.perim"), fmtLen(a.perim.toInt(), app.settings.unit, en) + " " + app.unitName())
                    a.net?.let { Hairline(); Kv2(tr("rp.net"), fmtArea(it, en) + " " + tr("u.m2")) }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("info", G.ink2, 18.dp, 2f)
            Text(tr("es.areasNote") + " " + tr("rp.conv"), style = ui(13f, 400, G.ink2, 1.45f), modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun Kv2(k: String, v: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(k, style = ui(14f, 400, G.ink2), modifier = Modifier.weight(1f)); Text(v, style = uz.metrx.app.ui.theme.num(15f, 700))
    }
}

/** What a typed number is wrong with, in words (prototype msg()); null when fine or empty. */
private fun decErr(d: Dec, t: (String, Array<out Pair<String, Any?>>) -> String): String? = when (d) {
    is Dec.Ok, Dec.Empty -> null
    Dec.Format -> t("err.format", emptyArray())
    Dec.Negative -> t("err.negative", emptyArray())
    is Dec.Precision -> if (d.n > 0) t("err.precision", arrayOf("n" to d.n)) else t("err.whole", emptyArray())
}

/** +10 % on a typed quantity, to 3 decimals (prototype resQ: Math.round(n · 1.1 · 1000) / 1000). */
private fun withSpare(q: String): String = BigDecimal(canonOf(q).ifEmpty { "0" }).multiply(BigDecimal("1.1")).setScale(3, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString()

/** A new or existing estimate row (prototype SHEETS.row, glass "Yangi material"), keeping a draft when left unsaved. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RowSheet(s0: Sheet.Row) {
    val app = LocalApp.current
    val lang = LocalLang.current; val en = lang == Lang.EN
    val p = app.store.get(s0.pid) ?: run { app.sheet = null; return }
    var kind by remember { mutableStateOf(s0.kind) }
    val mat = kind == "mat"
    val existing = s0.id?.let { id -> (if (mat) p.estimate.materials else p.estimate.labor).firstOrNull { it.id == id } }
    fun key(k: String) = p.id + "|" + k + "|" + (s0.id ?: "new")
    // [fresh]: the empty form "Save and add another" starts again with, without the suggested name and unit
    fun initial(k: String, fresh: Boolean = false): Map<String, String> {
        val x = s0.id?.let { id -> (if (k == "mat") p.estimate.materials else p.estimate.labor).firstOrNull { it.id == id } }
        val sn = if (fresh) null else s0.name
        return if (k == "mat") mapOf("ename" to (x?.let { dn(it.name, lang) } ?: sn ?: ""), "eunit" to (x?.unit ?: (if (fresh) null else s0.unit) ?: "@u.pcs"),
            "eqty" to (x?.qty?.replace('.', if (en) '.' else ',') ?: ""), "eprice" to (x?.price ?: ""), "ereserve" to "")
        else mapOf("ename" to (x?.let { dn(it.name, lang) } ?: sn ?: ""), "eamount" to (x?.amount ?: ""))
    }
    var init by remember { mutableStateOf(initial(s0.kind)) }
    // a suggestion button opens a fresh sheet; otherwise a kept draft comes back
    var form by remember { mutableStateOf(if (s0.name != null) init else app.settings.rowDrafts[key(s0.kind)] ?: init) }
    var restored by remember { mutableStateOf(s0.name == null && app.settings.rowDrafts.containsKey(key(s0.kind))) }
    var touched by remember { mutableStateOf(setOf<String>()) }
    var tried by remember { mutableStateOf(false) }
    var closing by remember { mutableStateOf(false) }   // saved or deleted: nothing to keep
    fun f(k: String) = form[k] ?: ""
    // the +10 % spare is for m² only: another unit turns it off (its chip is gone, so it could not be seen)
    fun set(k: String, v: String) { form = form + (k to v) + (if (k == "eunit" && v != "@u.m2") mapOf("ereserve" to "") else emptyMap()) }
    if (existing == null && s0.id != null) { app.sheet = null; return }

    // leaving the sheet (×, outside, Back, another tab) keeps what was typed; going to the background keeps it too
    val dirty = { val typed = listOf("ename", "eqty", "eprice", "eamount").any { f(it).isNotBlank() }; form != init && (typed || s0.id != null) }
    val cur by rememberUpdatedState(Triple(dirty, key(kind), form))
    val life = LocalLifecycleOwner.current
    DisposableEffect(Unit) {
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_STOP && !closing && cur.first()) app.settings.setDraft(cur.second, cur.third) }
        life.lifecycle.addObserver(obs)
        onDispose {
            life.lifecycle.removeObserver(obs)
            if (!closing) {
                if (cur.first()) { app.settings.setDraft(cur.second, cur.third); app.say("gs.dKept", kind = ToastKind.INFO) }
                else if (app.settings.rowDrafts.containsKey(cur.second)) app.settings.setDraft(cur.second, null)
            }
        }
    }

    val t: (String, Array<out Pair<String, Any?>>) -> String = { k, v -> app.t(k, *v) }
    val nameErr = if (f("ename").isBlank()) tr("re.nameReq") else null
    val q = if (mat) parseDec(f("eqty"), 3) else Dec.Empty
    val pr = parseDec(if (mat) f("eprice") else f("eamount"), p.precision)
    val qErr = if (mat) decErr(q, t) else null
    val pErr = decErr(pr, t)
    val reserve = f("ereserve") == "1" && f("eunit") == "@u.m2"
    val qShown = if (mat && q is Dec.Ok) (if (reserve) fmtNumStr(withSpare(f("eqty")), en) else fmtNumStr(canonOf(f("eqty")), en)) else null
    val lt: BigInteger? = if (mat) { if (q is Dec.Ok && pr is Dec.Ok) lineTotal(if (reserve) withSpare(f("eqty")) else f("eqty"), f("eprice"), p.precision) else null } else pr.value()
    val formula = if (mat) "${qShown ?: "?"} ${dn(f("eunit"), lang)} × ${pr.value()?.let { money(it, p, lang) } ?: "?"} ${curSuffix(p.currency, lang)}" + (if (reserve) " · " + tr("gs.withRes") else "")
        else tr("gs.agreed")
    val bad = nameErr != null || qErr != null || pErr != null

    fun save(again: Boolean) {
        if (bad) { tried = true; return }
        val qty = if (f("eqty").isBlank()) "" else canonOf(if (reserve) withSpare(f("eqty")) else f("eqty"))
        // a calculator line changed by hand becomes the maker's own ("t-" lines are replaced on "Smetani yangilash")
        val id = s0.id?.let { if (it.startsWith("t-") && form != init) uid() else it } ?: uid()
        // an untouched name keeps its key, so it still follows the language
        val name = f("ename").trim().let { n -> if (existing != null && n == dn(existing.name, lang)) existing.name else n }
        val row = if (mat) Row(id, name, f("eunit"), qty, if (f("eprice").isBlank()) "" else canonOf(f("eprice")))
            else Row(id, name, amount = if (f("eamount").isBlank()) "" else canonOf(f("eamount")))
        app.store.update(p.id) { pp ->
            val e = pp.estimate
            fun List<Row>.put() = if (s0.id != null) map { if (it.id == s0.id) row else it } else this + row
            pp.copy(stage = if (pp.stage == "measure") "estimate" else pp.stage,
                estimate = if (mat) e.copy(materials = e.materials.put()) else e.copy(labor = e.labor.put()))
        }
        app.settings.setDraft(key(kind), null)
        if (s0.id != null) app.say("op.saved", "o" to dn(row.name, lang)) else app.say("re.added")
        // the same sheet stays open (a new Sheet.Row(p.id, kind) would equal this one), so its form starts again here
        if (again) { init = initial(kind, fresh = true); form = init; restored = false; touched = emptySet(); tried = false }
        else { closing = true; app.sheet = null }
    }
    fun delete() {
        closing = true
        app.settings.setDraft(key(kind), null)
        val gone = existing ?: return
        val idx = (if (mat) p.estimate.materials else p.estimate.labor).indexOfFirst { it.id == gone.id }
        app.store.update(p.id) { pp -> val e = pp.estimate; pp.copy(estimate = if (mat) e.copy(materials = e.materials.filter { it.id != s0.id }) else e.copy(labor = e.labor.filter { it.id != s0.id })) }
        app.sheet = null
        // Undo puts the row back where it was
        app.say("re.deleted", action = "common.undo") {
            app.store.update(p.id) { pp ->
                val e = pp.estimate
                fun List<Row>.back() = if (any { it.id == gone.id }) this else toMutableList().apply { add(idx.coerceIn(0, size), gone) }
                pp.copy(estimate = if (mat) e.copy(materials = e.materials.back()) else e.copy(labor = e.labor.back()))
            }
        }
    }

    val title = if (s0.id != null) tr("gs.edit") else tr(if (mat) "re.newMat" else "re.newLab")
    GlassSheet(title, { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            if (s0.id != null) Box(Modifier.size(54.dp).clip(CircleShape).background(if (Theme.dark) G.errWash else Color(0xB3FEE2E2)).border(.67.dp, Color(0x40DC2626), CircleShape)
                .pressable({ delete() }, .95f, label = tr("gs.del")), contentAlignment = Alignment.Center) { MIcon("trash", if (Theme.dark) G.err else Color(0xFFB91C1C), 20.dp, 2f) }
            else GBtn(tr("gs.again"), { save(true) }, Btn.SECONDARY, modifier = Modifier.weight(1f).alpha(if (bad) .5f else 1f), height = 54.dp, corner = 27.dp, fontSize = 15f)
            GBtn(tr("common.save"), { save(false) }, modifier = Modifier.weight(if (s0.id != null) 1f else 1.4f).alpha(if (bad) .5f else 1f), height = 54.dp, corner = 27.dp, fontSize = 15f)
        }
    }) {
        if (restored) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.cobalt.copy(alpha = .08f)).padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("info", G.cobalt, 18.dp, 2f)
            Text(tr("gs.dBack"), style = ui(13.5f, 600), modifier = Modifier.weight(1f))
            Text(tr("gs.dClear"), style = ui(13.5f, 700, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) {
                app.settings.setDraft(key(kind), null); form = init; restored = false; touched = emptySet(); tried = false }.padding(horizontal = 10.dp, vertical = 8.dp))
        }
        if (s0.id == null) KindSeg(kind) { k ->
            if (k == kind) return@KindSeg
            val name = f("ename")
            if (dirty()) app.settings.setDraft(key(kind), form)
            kind = k; init = initial(k) + ("ename" to name)
            val dr = app.settings.rowDrafts[key(k)]
            form = dr ?: init; restored = dr != null; touched = emptySet(); tried = false
        }
        val qtyFocus = remember { FocusRequester() }; val priceFocus = remember { FocusRequester() }; val nameFocus = remember { FocusRequester() }
        // a new row starts with the cursor in its name (prototype setFocus('ename'))
        if (s0.id == null && s0.name == null) androidx.compose.runtime.LaunchedEffect(Unit) { kotlinx.coroutines.delay(300); runCatching { nameFocus.requestFocus() } }
        Column {
            GField(tr("gs.name"), f("ename"), { set("ename", it) }, placeholder = tr(if (mat) "gs.phMat" else "gs.phLab"), error = nameErr,
                showError = tried || "ename" in touched, onBlur = { touched = touched + "ename" }, onIme = { qtyFocus.requestFocus() }, focusRequester = nameFocus)
            val sugg = tr(if (mat) "gs.sMat" else "gs.sLab").split('|')
            Row(Modifier.padding(top = 8.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                sugg.forEachIndexed { i, n ->
                    Text(n, style = ui(13f, 600, G.cobalt2), maxLines = 1, modifier = Modifier.height(34.dp).clip(RoundedCornerShape(17.dp)).background(G.cobalt.copy(alpha = .07f))
                        .border(.67.dp, G.cobalt.copy(alpha = .2f), RoundedCornerShape(17.dp)).clickable(role = Role.Button) {
                            form = form + ("ename" to n)
                            if (mat) set("eunit", SUG_UNITS.getOrNull(i) ?: f("eunit"))
                        }.padding(horizontal = 12.dp, vertical = 7.dp))
                }
            }
        }
        if (mat) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tr("gs.unit"), style = ui(15f, 700))
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    UNITS.forEach { u ->
                        val on = f("eunit") == "@$u"
                        val shape = RoundedCornerShape(20.dp)
                        Text(tr(u), style = ui(14f, if (on) 700 else 600, if (on) Color.White else G.ink), maxLines = 1,
                            modifier = Modifier.let { if (on) it.dropShadow(shape, Shadow(14.dp, G.cobalt.copy(alpha = .3f), offset = DpOffset(0.dp, 6.dp))) else it }
                                .height(40.dp).clip(shape).background(if (on) G.cobalt else G.idle(.85f))
                                .border(.67.dp, if (on) G.cobalt else G.ink.copy(alpha = .1f), shape).clickable(role = Role.RadioButton) { set("eunit", "@$u") }
                                .padding(horizontal = 16.dp, vertical = 10.dp))
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                NumField(tr("gs.qty"), f("eqty"), { set("eqty", it) }, dn(f("eunit"), lang), qErr, tried || "eqty" in touched, onBlur = { touched = touched + "eqty" },
                    onIme = { priceFocus.requestFocus() }, focusRequester = qtyFocus, modifier = Modifier.weight(1f))
                NumField(tr("gs.price"), f("eprice"), { set("eprice", it) }, curSuffix(p.currency, lang), pErr, tried || "eprice" in touched, onBlur = { touched = touched + "eprice" },
                    imeAction = androidx.compose.ui.text.input.ImeAction.Done, focusRequester = priceFocus, modifier = Modifier.weight(1f))
            }
            val ga = pjAreas(p, app.settings.angleSnap)
            if (f("eunit") == "@u.m2" && (ga.nw > 0 || ga.nf > 0)) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tr("gs.fromRoom"), style = ui(15f, 700))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    fun area(mm2: Long) = BigDecimal(mm2).divide(BigDecimal(1_000_000)).setScale(2, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString().replace('.', if (en) '.' else ',')
                    if (ga.nw > 0) FromChip(tr("gs.wall") + " " + fmtArea(ga.w, en)) { set("eqty", area(ga.w)); touched = touched + "eqty" }
                    if (ga.nf > 0) FromChip(tr("gs.floor") + " " + fmtArea(ga.f, en)) { set("eqty", area(ga.f)); touched = touched + "eqty" }
                    ReserveChip(reserve) { set("ereserve", if (reserve) "" else "1") }
                }
            }
        } else NumField(tr("gs.sum"), f("eamount"), { set("eamount", it) }, curSuffix(p.currency, lang), pErr, tried || "eamount" in touched, onBlur = { touched = touched + "eamount" },
            imeAction = androidx.compose.ui.text.input.ImeAction.Done, focusRequester = qtyFocus)
        // the line total, worked out as it is typed
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(G.cobalt.copy(alpha = .08f)).border(.67.dp, G.cobalt.copy(alpha = .16f), RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f)) {
                Text(tr("gs.line"), style = ui(13f, 700, G.slate))
                Text(formula, style = ui(12f, 400, G.ink2, 1.35f))
            }
            Text(lt?.let { money(it, p, lang, true) } ?: "—", style = ui(20f, 800, COB_DARK), maxLines = 1)
        }
        Text(tr("gs.later"), style = ui(12f, 400, G.ink2))
        if (pErr == null && pr is Dec.Ok && pr.v.signum() == 0) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.cobalt.copy(alpha = .08f)).padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.cobalt, 18.dp, 2f); Text(tr("re.zero"), style = ui(13.5f, 500), modifier = Modifier.weight(1f)) }
    }
}

/** Material | Labour for a new row (prototype .gs-seg). */
@Composable
private fun KindSeg(cur: String, onPick: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        listOf("mat" to tr("gs.mat"), "lab" to tr("gs.lab")).forEach { (k, l) ->
            val on = k == cur
            val shape = RoundedCornerShape(13.dp)
            Box(Modifier.weight(1f).let { if (on) it.dropShadow(shape, Shadow(3.dp, Color(0x24101828), offset = DpOffset(0.dp, 1.dp))) else it }.height(42.dp).clip(shape)
                .background(if (on) G.glass(.95f) else Color.Transparent).clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 14.dp),
                contentAlignment = Alignment.CenterStart) { Text(l, style = ui(14f, if (on) 700 else 600, if (on) G.ink else G.ink2), maxLines = 1) }
        }
    }
}

@Composable
private fun FromChip(label: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(19.dp)
    Row(Modifier.dropShadow(shape, Shadow(8.dp, G.shade.copy(alpha = .06f), offset = DpOffset(0.dp, 2.dp))).height(38.dp).clip(shape).background(G.glass(.8f))
        .border(.67.dp, G.rim, shape).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        PathIcon(P_PLAN, G.cobalt, 16.dp, 2.2f); Text(label, style = ui(13f, 600), maxLines = 1)
    }
}

@Composable
private fun ReserveChip(on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(19.dp)
    Box(Modifier.dropShadow(shape, Shadow(8.dp, G.shade.copy(alpha = .06f), offset = DpOffset(0.dp, 2.dp))).height(38.dp).clip(shape)
        .background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.8f))
        .drawBehind {
            val w = .67.dp.toPx()
            drawRoundRect(if (on) G.cobalt else G.ink.copy(alpha = .2f), Offset(w / 2, w / 2), androidx.compose.ui.geometry.Size(size.width - w, size.height - w), androidx.compose.ui.geometry.CornerRadius(19.dp.toPx()),
                style = Stroke(if (on) 1.5.dp.toPx() else w, pathEffect = if (on) null else PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
        }
        .clickable(role = Role.Switch, onClick = onClick).padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            if (on) MIcon("check", G.cobalt, 14.dp, 2.6f)
            Text(tr("gs.reserve"), style = ui(13f, 700, if (on) G.cobalt2 else G.slate), maxLines = 1)
        }
    }
}
