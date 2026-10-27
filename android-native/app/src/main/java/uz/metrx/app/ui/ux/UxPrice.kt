package uz.metrx.app.ui.ux

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.dn
import uz.metrx.app.data.fmtDate
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

private val DARK = Color(0xFF0E1C36)

/**
 * "Narx va yuborish" (UX upgrades §4, §8): the quote's card (draft or issued), the price (simple mode grey and
 * approximate; Advanced exact with cost and profit), the PDF's two buttons with their full words, and at the bottom the
 * big "Telegram’ga yuborish", which issues the quote at once, with "Boshqa…" under it for the share sheet. Advanced
 * keeps the price working, the three options, the documents and the issued quotes below.
 */
@Composable
fun FPriceScreen(rt: Route.FPrice) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ctx = LocalContext.current
    val p = app.store.get(rt.pid) ?: return
    val s = app.settings
    val en = lang == Lang.EN
    // the Narx step is done once the price was seen
    LaunchedEffect(p.id, p.furniture.isNotEmpty()) { if (p.furniture.isNotEmpty() && !p.priced) app.store.update(p.id, touch = false) { it.copy(priced = true) } }
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    val pr = remember(p.furniture, p.fprice, s.workshop, s.mats, s.hws) { priceOf(fs, p.fprice, s.workshop, s.mats, s.hws) }
    val cur = remember(p, s.workshop, s.mats, s.hws, s.pdf, s.builderName) { app.currentQuote(p) }
    val no = cur?.no ?: ((p.quotes.maxOfOrNull { it.no } ?: 0) + 1)
    Column(Modifier.fillMaxSize()) {
        UxTop(tr("ux.priceT"), { app.pop() }, eyebrow = dn(p.name, lang)) { ProgressRow(p) }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (fs.isEmpty()) {
                Text(tr("fp.empty"), style = ui(14.5f, 500, G.ink2, 1.45f), textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
                return@Column
            }
            // the quote's card
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.62f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("q.no", "n" to no), style = ui(17f, 800), modifier = Modifier.weight(1f))
                    if (cur != null) Row(Modifier.clip(RoundedCornerShape(10.dp)).background(G.greenWash).padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        MIcon("lock", G.green, 13.dp, 2.2f)
                        Text(tr("ux.issuedAt", "d" to fmtDate(cur.ts) + " " + uz.metrx.app.ui.report.fmtTime(cur.ts)), style = ui(12f, 700, G.green), maxLines = 1)
                    } else Text(tr("es.draft"), style = ui(12f, 700, G.amberInk), modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(G.amberWash).padding(horizontal = 9.dp, vertical = 4.dp))
                }
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(DARK).padding(14.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    if (s.advanced) {
                        Text(tr("fp.price"), style = ui(12.5f, 400, Color(0xFFB7C3D9)))
                        Text(app.moneyText(p, pr.price), style = num(25f, 800, Color.White), maxLines = 1)
                        val pc = pr.profitPct10
                        Text(tr("ux.costProfit", "c" to app.moneyText(p, pr.cost.total), "p" to app.moneyText(p, pr.profit),
                            "pc" to "${if (pc < 0) "−" else ""}${kotlin.math.abs(pc) / 10}${if (en) "." else ","}${kotlin.math.abs(pc) % 10}"),
                            style = ui(12.5f, 600, if (pr.profit.signum() < 0) Color(0xFFFCA5A5) else Color(0xFF86EFAC), 1.35f))
                    } else {
                        Text(tr("ux.approxT"), style = ui(12.5f, 400, Color(0xFFB7C3D9)))
                        Text(app.priceWords(p, short = true) ?: "—", style = num(25f, 700, Color(0xFFCBD5E1)), maxLines = 1)
                        Text(tr("ux.advHint"), style = ui(12f, 400, Color(0xFFB7C3D9), 1.35f))
                    }
                }
                Kv(tr("ux.kv.client"), dn(p.customer, lang).ifBlank { "—" })
                Hairline()
                Kv(tr("ux.kv.furn"), fs.joinToString(", ") { dn(it.name, lang) })
                val style = p.fstyle.ifEmpty { fs.firstOrNull()?.look?.preset.orEmpty() }
                if (style.isNotEmpty()) { Hairline(); Kv(tr("ux.kv.style"), tr("lk.p.$style")) }
            }
            // the PDF: the draft or issuing it; both buttons keep their whole words (two lines when needed)
            Text(tr("ux.pdfT"), style = ui(15f, 800), modifier = Modifier.padding(top = 4.dp, start = 4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GBtn(tr("rp2.shareDraft"), { app.shareDraft(ctx, p.id) }, Btn.SECONDARY, icon = "share", modifier = Modifier.weight(1f), maxLines = 2, fontSize = 15f)
                GBtn(tr("rpt.issue"), { app.issueOnly(ctx, p.id) }, Btn.SECONDARY, icon = "lock", enabled = cur == null, modifier = Modifier.weight(1f), maxLines = 2, fontSize = 15f)
            }
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).clickable(role = Role.Button) {
                app.push(if (cur != null) Route.Quote(p.id, cur.no) else Route.Report(p.id)) }.padding(horizontal = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon("doc", G.cobalt2, 18.dp, 2f)
                Text(tr("fo.preview"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.weight(1f))
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
            // the client's 3D file goes through the share sheet (the "Boshqa…" kind of sending)
            GBtn(tr("sh3.btn"), { app.sheet = Sheet.Share3D(p.id) }, Btn.SECONDARY, icon = "cube", height = 50.dp, corner = 16.dp, fontSize = 14.5f, maxLines = 2)
            if (s.advanced) Text(tr("ux.details"), style = ui(15f, 800), modifier = Modifier.padding(top = 8.dp, start = 4.dp))
        }
        if (s.advanced && fs.isNotEmpty()) AdvancedPart(p)
        }
        val tg = p.quotes.isNotEmpty() && cur != null
        UxBar(tr(if (tg) "ux.a.resend" else "ux.a.tg"), "tg", { app.sendQuote(ctx, p.id, telegram = true) }, onUndo = { app.undoLast() }, canUndo = app.undos.isNotEmpty(),
            coach = "price", mainColor = Color(0xFF2AABEE), mainEnabled = fs.isNotEmpty()) {
            Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button, enabled = fs.isNotEmpty()) { app.sendQuote(ctx, p.id, telegram = false) },
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("share", G.cobalt2, 16.dp, 2f)
                Text(tr("ux.other"), style = ui(14.5f, 700, G.cobalt2))
            }
        }
    }
}

/** Advanced: the price working, the three options, the documents and costs (the old Narx tab), then the issued quotes. */
@Composable
private fun AdvancedPart(p: uz.metrx.app.data.Project) {
    val lang = LocalLang.current
    // the old Narx tab and quotes list draw with their own side margins
    uz.metrx.app.ui.furniture.FPriceTab(p)
    if (p.quotes.isNotEmpty()) {
        Text(tr("ux.quotesT"), style = ui(15f, 800), modifier = Modifier.padding(top = 18.dp, start = 20.dp))
        uz.metrx.app.ui.projects.QuotesTab(p, lang, issueBar = false)
    }
}

@Composable
private fun Kv(k: String, v: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(k, style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(top = 1.dp))
        Text(v, style = ui(14.5f, 600), textAlign = TextAlign.End, modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
    }
}
