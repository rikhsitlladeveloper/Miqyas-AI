package uz.metrx.app.ui.furniture

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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Dec
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.core.parseDec
import uz.metrx.app.core.shortMoney
import uz.metrx.app.data.F_STAGES
import uz.metrx.app.data.Project
import uz.metrx.app.data.addPayment
import uz.metrx.app.data.approve
import uz.metrx.app.data.dn
import uz.metrx.app.data.fStage
import uz.metrx.app.data.fmtDate
import uz.metrx.app.data.halfOf
import uz.metrx.app.data.nextStage
import uz.metrx.app.data.orderMoney
import uz.metrx.app.data.owed
import uz.metrx.app.data.prevStage
import uz.metrx.app.data.removePayment
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassHeader
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.LogoTile
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.main.MainNav
import uz.metrx.app.ui.main.NAV_SPACE
import uz.metrx.app.ui.main.Tab
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigInteger

/*
 * Furniture makers, Stage 1a part 1 (design/furniture/FURNITURE_PLAN.md, sections 3 and 4; design canvas screens 1–5):
 * the industry picker, the furniture Home, order rows, the order's stages and its payments.
 */

private const val BUILD_ICON = "M6 8h28v24H6z M6 20h12v12 M24 8v10h10"
private const val FURN_ICON = "M4 6h32v9H4z M4 22h32v14H4z M3 20h34 M20 6v9 M15 22v14 M27 22v14"
/** The trades on the picker, with their pictures (40-unit box). */
private val TRADE_CARDS = listOf(
    "tiler" to "M6 6h13v13H6z M21 6h13v13H21z M6 21h13v13H6z M21 21h13v13H21z",
    "elec" to "M22 4L10 22h9l-2 14 13-19h-9l1-13z",
    "plumb" to "M8 8h14v8h8v16 M22 16v-4 M30 32h4 M4 8h4",
    "win" to "M8 4h24v32H8z M20 4v32 M8 20h24"
)
private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
const val SHEET_ICON = "M3 3h18v18H3z M3 12h11v9 M14 3v9 M14 8h7"
private const val ARROW = "M7 17L17 7M9 7h8v8"

/** Money of a project in its currency, "12 500 000 so‘m". */
@Composable
private fun money(p: Project, v: BigInteger): String {
    val lang = LocalLang.current
    return moneyStr(v, p.precision, lang == Lang.EN) + " " + curSuffix(p.currency, lang)
}

/* ---------------- the industry picker (first run, after sign-in) ---------------- */

@Composable
fun IndustryScreen(onBack: () -> Unit, onPick: (String) -> Unit) {
    val app = LocalApp.current
    var pick by rememberSaveable { mutableStateOf<String?>(null) }
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GlassIconButton("back", tr("nt.back"), onBack)
            LogoTile(30.dp, 9.dp)
            Text("METRX", style = ui(16f, 700, G.ink, spacing = .32f))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(tr("ind.title"), style = ui(30f, 800, G.ink, 1.15f, -.02f))
            Text(tr("ind.lead"), style = ui(15f, 400, G.ink2, 1.45f), modifier = Modifier.padding(bottom = 8.dp))
            IndustryCard(BUILD_ICON, tr("ind.build"), tr("ind.buildS"), pick == "build") { pick = "build" }
            IndustryCard(FURN_ICON, tr("ind.furn"), tr("ind.furnS"), pick == "furniture") { pick = "furniture" }
            // the other trades: builders' projects with their own calculator (trades/Trades.kt)
            TRADE_CARDS.forEach { (k, icon) -> IndustryCard(icon, tr("ind.$k"), tr("ind.${k}S"), pick == k) { pick = k } }
        }
        GBtn(tr("ind.go"), { pick?.let(onPick) }, enabled = pick != null, modifier = Modifier.padding(top = 12.dp))
    }
}

@Composable
private fun IndustryCard(icon: String, title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(26.dp)
    Row(
        Modifier.fillMaxWidth().glassCard(shape).let { if (on) it.border(2.5.dp, G.cobalt, shape) else it }
            .semantics { selected = on }.pressable(onClick, .99f, role = Role.RadioButton).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(Modifier.size(64.dp).clip(RoundedCornerShape(20.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) {
            PathIcon(icon, G.cobalt, 40.dp, 2f, viewBox = 40f)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = ui(19f, 800))
            Text(sub, style = ui(13.5f, 400, G.ink2, 1.4f))
        }
        if (on) Box(Modifier.size(26.dp).clip(CircleShape).background(G.cobalt), contentAlignment = Alignment.Center) { MIcon("check", Color.White, 14.dp, 3f) }
    }
}

/* ---------------- Home for a furniture maker ---------------- */

@Composable
fun FurnitureHome(nav: MainNav) {
    val app = LocalApp.current
    val s = app.settings
    val lang = LocalLang.current
    val first = s.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("fo.lines").split('|')
    // the soonest install first (late ones on top), then the undated ones, newest first; paid orders last
    val orders = app.store.projects.filter { it.isFurniture }.let { all -> uz.metrx.app.data.sortOrders(all.filter { it.stage != "paid" }) + all.filter { it.stage == "paid" } }
    val (debt, nDebt) = owed(orders)
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        GlassHeader(nav::laser)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp + NAV_SPACE).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.padding(top = 18.dp, bottom = 8.dp)) {
                Text(if (first.isNotEmpty()) tr("hm.hi", "n" to first) else tr("hm.hi0"), style = ui(34f, 800, G.ink, 1.1f, -.02f))
                Text(lines[s.visit % lines.size], style = ui(17f, 500, G.slate, 1.35f), modifier = Modifier.padding(top = 8.dp).widthIn(max = 320.dp))
            }
            val big = RoundedCornerShape(30.dp)
            Row(Modifier.fillMaxWidth().glassCard(big, shadowRadius = 36.dp, shadowY = 16.dp, shadowAlpha = .15f).pressable(nav::newProject).padding(18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(56.dp).dropShadow(RoundedCornerShape(20.dp), Shadow(22.dp, G.cobalt.copy(alpha = .4f), offset = DpOffset(0.dp, 10.dp)))
                    .clip(RoundedCornerShape(20.dp)).background(G.cobalt).topHighlight(.45f), contentAlignment = Alignment.Center) { MIcon("plus", Color.White, 26.dp, 2.4f) }
                Column(Modifier.weight(1f)) {
                    Text(tr("fo.new"), style = ui(22f, 800, G.ink, 1.15f, -.01f))
                    Text(tr("fo.newS"), style = ui(14f, 400, G.ink2))
                }
                PathIcon(ARROW, G.ink, 20.dp, 2.2f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Tile(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                Tile(SHEET_ICON, tr("fo.sheets"), tr("fo.sheetsS"), { app.calc.tool = "sheet"; nav.calculator() }, Modifier.weight(1f))
            }
            if (nDebt > 0) Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(24.dp)).padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(tr("fo.owed"), style = ui(12.5f, 600, G.ink2))
                    Text(moneyStr(debt, 0, lang == Lang.EN) + " " + curSuffix(s.currency, lang), style = num(21f, 800))
                }
                Text(tr("fo.owedN", "n" to nDebt), style = ui(12.5f, 400, G.ink2), modifier = Modifier.widthIn(max = 120.dp))
            }
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.recent"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (orders.isNotEmpty()) Text(tr("fo.all"), style = ui(13.5f, 700, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.selectTab(Tab.PROJECTS) }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
            if (orders.isEmpty()) Text(tr("fo.noOrders"), style = ui(14f, 400, G.ink2, 1.45f))
            orders.take(3).forEach { p -> OrderLine(p) { app.push(Route.Project(p.id)) } }
        }
    }
}

@Composable
private fun Tile(icon: String, title: String, sub: String, onClick: () -> Unit, modifier: Modifier) {
    Column(modifier.heightIn(min = 112.dp).glassCard(RoundedCornerShape(26.dp)).pressable(onClick).padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
        PathIcon(icon, G.cobalt, 24.dp, 2f)
        Spacer(Modifier.height(18.dp))
        Text(title, style = ui(17f, 700)); Text(sub, style = ui(12.5f, 400, G.ink2))
    }
}

@Composable
private fun OrderLine(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp)).pressable(onClick).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(dn(p.name, lang), style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) { FStageChip(p.stage); InstallChip(p) }
        }
        CallButton(p)
    }
}

/** A furniture order's stage as a coloured chip. */
@Composable
fun FStageChip(stage: String) {
    val (bg, fg) = when (stage) {
        "measure", "production" -> G.amberWash to G.amberInk
        "installed", "paid" -> Color(0x2416A34A) to (if (Theme.dark) G.green else Color(0xFF15803D))
        else -> G.cobalt.copy(alpha = .12f) to G.cobalt2
    }
    Text(tr("fs.$stage"), style = ui(12f, 600, fg), maxLines = 1, modifier = Modifier.clip(CircleShape).background(bg).padding(horizontal = 10.dp, vertical = 4.dp))
}

/** One order in the Orders list: name, who, the 7 stages as a bar, the stage and install date, what is left; the call button. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun OrderRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    val m = orderMoney(p)
    val k = fStage(p)
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(24.dp)).pressable(onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(dn(p.name, lang), style = ui(15.5f, 700, G.ink, 1.25f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                val sub = orderSub(p, lang, " · ")
                if (sub.isNotEmpty()) Text(sub, style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                F_STAGES.indices.forEach { i -> Box(Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(3.dp)).background(if (i <= k) G.cobalt else G.ink.copy(alpha = .12f))) }
            }
            androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                FStageChip(p.stage)
                InstallChip(p)
                val left = m.left
                if (left != null && k >= 3 && left.signum() > 0) Text(tr("fo.leftV", "v" to money(p, left)), style = ui(12.5f, 700, G.amberInk), modifier = Modifier.padding(vertical = 4.dp))
            }
        }
        CallButton(p)
    }
}

/** The order page's three numbers: stage, agreed price, paid. */
@Composable
fun FNums(p: Project) {
    val lang = LocalLang.current
    val m = orderMoney(p)
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Cell(tr("fo.stage"), "${fStage(p) + 1}/${F_STAGES.size}", null, Modifier.weight(.8f))
            // until the price is agreed: the Narx tab's estimate, grey
            val app = uz.metrx.app.ui.LocalApp.current
            val st = app.settings
            val est = if (m.agreed != null) null else androidx.compose.runtime.remember(p.furniture, p.fprice, st.workshop, st.mats, st.hws) {
                uz.metrx.app.furniture.priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, st.workshop, st.mats, st.hws).price.takeIf { it.signum() > 0 } }
            val (a, au) = when {
                m.agreed != null -> shortMoney(p, m.agreed, lang == Lang.EN, tr("pl.mln"))
                est != null -> shortMoney(p, est, lang == Lang.EN, tr("pl.mln")).let { "≈ " + it.first to it.second }
                else -> "—" to null
            }
            Cell(tr("fo.agreed"), a, au, Modifier.weight(1.3f), grey = est != null, note = if (est != null) tr("fo.est") else null)
            // the install date: worked out once approved; tap to change it
            val d = uz.metrx.app.data.installDate(p)
            val late = d != null && fStage(p) < 5 && d.isBefore(java.time.LocalDate.now())
            Cell(tr("fo.install"), d?.let { fmtDay(it, app) } ?: "—", null,
                Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).clickable(enabled = d != null, role = Role.Button) { app.sheet = uz.metrx.app.ui.Sheet.FInstall(p.id) },
                color = if (late) G.err else null, note = if (d == null) tr("fo.afterOk") else null)
        }
    }
}

@Composable
private fun Cell(label: String, value: String, unit: String?, modifier: Modifier, grey: Boolean = false, note: String? = null, color: Color? = null) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, style = num(17f, if (grey) 600 else 800, color ?: if (grey) G.ink3 else G.ink), maxLines = 1)
            if (unit != null) Text(" $unit", style = ui(10.5f, 600, G.ink2), modifier = Modifier.padding(bottom = 2.dp))
        }
        if (note != null) Text(note, style = ui(11f, 500, G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/* ---------------- Details tab: stages and payments ---------------- */

@Composable
fun FurnitureInfo(p: Project) {
    val app = LocalApp.current
    val m = orderMoney(p)
    val k = fStage(p)
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(tr("fo.stage"), style = ui(15f, 800), modifier = Modifier.padding(bottom = 4.dp))
            F_STAGES.forEachIndexed { i, st ->
                val done = i < k; val cur = i == k
                Row(Modifier.fillMaxWidth().heightIn(min = 36.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(26.dp).clip(CircleShape).background(if (done) G.cobalt else if (cur) G.solid else Color.Transparent)
                        .border(2.dp, if (done || cur) G.cobalt else G.ink3.copy(alpha = .35f), CircleShape), contentAlignment = Alignment.Center) {
                        if (done) MIcon("check", Color.White, 13.dp, 3f) else Text("${i + 1}", style = ui(12f, 800, if (cur) G.cobalt2 else G.ink3))
                    }
                    Text(tr("fs.$st"), style = ui(14.5f, if (cur) 800 else 600, if (i > k) G.ink3 else G.ink), modifier = Modifier.weight(1f))
                    if (st == "approved" && k >= 3 && m.agreed != null) Text(money(p, m.agreed), style = ui(12.5f, 400, G.ink2))
                }
            }
            when {
                k == 2 -> GBtn(tr("fo.next", "s" to tr("fs.approved")), { app.sheet = Sheet.FApprove(p.id) }, modifier = Modifier.padding(top = 8.dp))
                k < 5 -> GBtn(tr("fo.next", "s" to tr("fs." + F_STAGES[k + 1])), {
                    val q = app.store.update(p.id) { nextStage(it) }
                    if (q?.stage == "paid") app.say("fs.paid")
                }, modifier = Modifier.padding(top = 8.dp))
                k == 5 -> Text(tr("fo.payLeft"), style = ui(13f, 400, G.ink2, 1.4f), modifier = Modifier.padding(top = 6.dp))
            }
            if (k > 0) Text(tr("fo.prev"), style = ui(13.5f, 600, G.cobalt2),
                modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                    .clickable(role = Role.Button) { app.store.update(p.id) { prevStage(it) } }.padding(horizontal = 10.dp, vertical = 12.dp))
        }

        Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.pays"), style = ui(15f, 800), modifier = Modifier.weight(1f))
                if (k >= 3 && (m.left?.signum() ?: 0) > 0)
                    GBtn(tr("fo.addPay"), { app.sheet = Sheet.FPay(p.id) }, Btn.SECONDARY, icon = "plus", height = 40.dp, corner = 14.dp, fontSize = 14f, fill = false)
            }
            if (m.agreed != null) Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Cell(tr("fo.agreed"), moneyStr(m.agreed, p.precision, LocalLang.current == Lang.EN), null, Modifier.weight(1f))
                Cell(tr("fo.paid"), moneyStr(m.paid, p.precision, LocalLang.current == Lang.EN), null, Modifier.weight(1f))
                Cell(tr("fo.left"), moneyStr(m.left ?: BigInteger.ZERO, p.precision, LocalLang.current == Lang.EN), null, Modifier.weight(1f))
            }
            if (p.payments.isEmpty()) Text(tr("fo.noPays"), style = ui(13f, 400, G.ink2, 1.4f))
            p.payments.reversed().forEach { pay ->
                Hairline()
                Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Column(Modifier.weight(1f)) {
                        Text(if (pay.pre) tr("fo.pre") else pay.note.ifBlank { tr("fo.pay") }, style = ui(14f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(fmtDate(pay.ts), style = ui(12f, 400, G.ink2))
                    }
                    Text("+" + money(p, pay.amount.toBigIntegerOrNull() ?: BigInteger.ZERO), style = num(14.5f, 800, G.green))
                    Box(Modifier.size(40.dp).clip(CircleShape).clickable(role = Role.Button) {
                        val before = p
                        app.store.update(p.id) { removePayment(it, pay.id) }
                        app.say("fo.payDel", action = "common.undo", onAction = { app.store.update(p.id) { before } })
                    }, contentAlignment = Alignment.Center) { MIcon("x", G.ink3, 16.dp, 2f) }
                }
            }
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun FurnitureSheet(s: Sheet): Boolean = when (s) {
    Sheet.Industry -> { IndustrySheet(); true }
    is Sheet.FApprove -> { ApproveSheet(s.pid); true }
    is Sheet.FPay -> { PaySheet(s.pid); true }
    is Sheet.PointForm -> { PointSheet(s); true }
    else -> false
}

@Composable
private fun IndustrySheet() {
    val app = LocalApp.current
    val cur = app.settings.industry
    GlassSheet(tr("ind.row"), { app.sheet = null }) {
        (listOf(Triple("build", "ind.build", "ind.buildS"), Triple("furniture", "ind.furn", "ind.furnS")) +
            uz.metrx.app.trades.TRADES.map { Triple(it, "ind.$it", "ind.${it}S") }).forEach { (k, t, sub) ->
            val on = cur == k
            val name = tr(t)
            Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(RoundedCornerShape(16.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
                .border(1.dp, if (on) G.cobalt.copy(alpha = .5f) else G.idleRim, RoundedCornerShape(16.dp))
                .clickable(role = Role.RadioButton) {
                    app.settings.setIndustryKind(k); app.sheet = null
                    if (k == "furniture" && app.calc.tool == "brick") app.calc.tool = "sheet"
                    if (k == "build" && app.calc.tool == "sheet") app.calc.tool = "area"
                    app.say("ind.set", "n" to name)
                }.padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(name, style = ui(16f, if (on) 700 else 600, if (on) G.cobalt2 else G.ink))
                    Text(tr(sub), style = ui(13f, 400, G.ink2))
                }
                if (on) MIcon("check", G.cobalt2, 20.dp, 2.4f)
            }
        }
    }
}

/** Typed money: null with the error key when it is not a positive whole amount in the project's precision. */
private fun parseMoney(text: String, precision: Int): Pair<BigInteger?, String?> = when (val d = parseDec(text, precision)) {
    is Dec.Ok -> if (d.v.signum() > 0) d.v to null else null to "fo.needPrice"
    Dec.Empty -> null to "fo.needPrice"
    is Dec.Precision -> null to "err.whole"
    else -> null to "err.whole"
}

@Composable
private fun ApproveSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: return
    val lang = LocalLang.current
    // the agreed price starts from the Narx tab's customer price
    var price by rememberSaveable { mutableStateOf(p.agreed.ifBlank {
        val s = app.settings
        uz.metrx.app.furniture.priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, s.workshop, s.mats, s.hws).price.takeIf { it.signum() > 0 }?.toString() ?: ""
    }) }
    var pre by rememberSaveable { mutableStateOf("") }
    var preTouched by rememberSaveable { mutableStateOf(false) }
    var tried by rememberSaveable { mutableStateOf(false) }
    val (pv, pErr) = parseMoney(price, p.precision)
    // the prepayment follows the price until it is typed: half of it
    val preText = if (preTouched) pre else pv?.let { halfOf(it).toString() } ?: ""
    val (rv, rErr0) = if (preText.isBlank()) BigInteger.ZERO to null else parseMoney(preText, p.precision)
    val rErr = rErr0 ?: if (pv != null && rv != null && rv > pv) "fo.preBig" else null
    val ok = pv != null && rErr == null
    GlassSheet(tr("fo.approveT"), { app.sheet = null }, footer = {
        GBtn(tr("fo.approve"), {
            tried = true
            if (!ok) return@GBtn
            app.store.update(pid) { approve(it, pv!!, rv ?: BigInteger.ZERO, System.currentTimeMillis()) }
            app.sheet = null; app.say("fo.approvedT")
        }, enabled = !tried || ok)
    }) {
        Text(tr("fo.approveB"), style = ui(14f, 400, G.ink2, 1.45f))
        GField(tr("fo.agreed"), price, { price = it.filter { c -> c.isDigit() } }, "0", error = pErr?.let { tr(it) }, showError = tried || price.isNotEmpty(),
            number = true, money = true, labelRight = curSuffix(p.currency, lang))
        GField(tr("fo.pre"), preText, { pre = it.filter { c -> c.isDigit() }; preTouched = true }, "0", optional = true, error = rErr?.let { tr(it) }, showError = true,
            number = true, money = true, imeAction = androidx.compose.ui.text.input.ImeAction.Done)
        if (pv != null && rv != null && rv.signum() > 0 && rErr == null)
            Text(tr("fo.prePct", "p" to (rv.multiply(BigInteger.valueOf(100)).divide(pv)).toString()), style = ui(13f, 400, G.ink2))
    }
}

@Composable
private fun PaySheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: return
    val lang = LocalLang.current
    val left = orderMoney(p).left
    var amount by rememberSaveable { mutableStateOf(left?.toString() ?: "") }
    var note by rememberSaveable { mutableStateOf("") }
    val (av, aErr0) = parseMoney(amount, p.precision)
    val aErr = aErr0 ?: if (av != null && left != null && av > left) "fo.tooMuch" else null
    GlassSheet(tr("fo.addPay"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if (aErr != null || av == null) return@GBtn
            val q = app.store.update(pid) { addPayment(it, av, note, System.currentTimeMillis()) }
            app.sheet = null
            app.say(if (q?.stage == "paid") "fs.paid" else "fo.payAdded")
        }, enabled = aErr == null)
    }) {
        if (left != null) Text(tr("fo.leftV", "v" to money(p, left)), style = ui(14f, 600, G.ink2))
        GField(tr("fo.amount"), amount, { amount = it.filter { c -> c.isDigit() } }, "0", error = aErr?.let { tr(it) }, showError = amount.isNotEmpty(),
            number = true, money = true, labelRight = curSuffix(p.currency, lang))
        GField(tr("fo.note"), note, { note = it }, "", optional = true, imeAction = androidx.compose.ui.text.input.ImeAction.Done)
    }
}
