package uz.metrx.app.ui.report

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.report.RPage
import uz.metrx.app.report.pageBitmap
import uz.metrx.app.report.pdfFile
import uz.metrx.app.report.pdfName
import uz.metrx.app.report.reportMeasurer
import uz.metrx.app.report.sharePdf
import uz.metrx.app.report.snapshotOf
import uz.metrx.app.report.workshopPages
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/** The workshop pack of a furniture order (furniture plan section 10): its pages, and sharing it. Never the customer's. */
@Composable
fun PackScreen(pid: String) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = LocalLang.current
    val p = app.store.get(pid) ?: return
    val s = app.settings
    val sn = remember(p, s.workshop, s.mats, s.hws) { snapshotOf(p, s) }
    val pr = remember(p, s.workshop, s.mats, s.hws) { priceOf(sn.furniture, p.fprice, s.workshop, s.mats, s.hws) }
    val tm = remember { reportMeasurer(ctx) }
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    var viewer by remember { mutableStateOf<Int?>(null) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wPx = with(density) { (maxWidth - 32.dp).roundToPx() }
        val built by produceState<Pair<List<RPage>, List<ImageBitmap>>?>(null, sn, pr, wPx) {
            value = withContext(Dispatchers.Default) {
                val pages = workshopPages(tm, sn, s.workshop, s.mats, s.hws, pr, p.fprice.mode)
                pages to pages.map { pageBitmap(it, wPx) }
            }
        }
        val pages = built?.first.orEmpty(); val bmps = built?.second.orEmpty()
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(start = 14.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(tr("fw.title"), style = ui(17f, 700, G.ink, 1.2f), maxLines = 1)
                    Text(dn(p.name, lang), style = ui(12.5f, 400, G.ink2, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color(0xFF7A2E0E)).padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(tr("fw.inside"), style = ui(12f, 700, Color(0xFFFDE2C8)))
                        Text(tr("fw.costShort", "v" to moneyStr(pr.cost.total, p.precision, lang == Lang.EN) + " " + curSuffix(p.currency, lang)), style = ui(16f, 700, Color.White).copy(fontFamily = PlexCond), maxLines = 1)
                    }
                    Text(if (pages.isEmpty()) "…" else tr("rp2.pages", "n" to pages.size), style = ui(12.5f, 400, Color(0xFFFDE2C8)))
                }
                val pager = rememberPagerState { bmps.size.coerceAtLeast(1) }
                HorizontalPager(pager, Modifier.fillMaxWidth()) { i ->
                    Box(Modifier.fillMaxWidth().aspectRatio(595f / 842f).dropShadow(RoundedCornerShape(6.dp), Shadow(14.dp, Color(0x24101828), offset = DpOffset(0.dp, 2.dp)))
                        .clip(RoundedCornerShape(6.dp)).background(Color.White).clickable(role = Role.Image) { if (bmps.isNotEmpty()) viewer = i }) {
                        bmps.getOrNull(i)?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds) }
                    }
                }
                Text(tr("rp2.of", "i" to pager.currentPage + 1, "n" to pages.size.coerceAtLeast(1)) + " · " + tr("rp2.tapZoom"), style = ui(12.5f, 400, G.ink2), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
            FloatingFooter {
                GBtn(tr("rpt.share"), {
                    val pg = built?.first ?: return@GBtn
                    app.say("sh.making", kind = ToastKind.INFO)
                    val fname = pdfName(dn(p.name, lang), app.t("fw.file"))
                    scope.launch {
                        runCatching { withContext(Dispatchers.Default) { pdfFile(ctx, pg, fname) } }
                            .onSuccess { sharePdf(ctx, it, app.t("sh.title")) }
                            .onFailure { app.say("cm.shareErr", kind = ToastKind.ERROR) }
                    }
                }, icon = "share")
            }
        }
        viewer?.let { start -> PageViewer(pages, start) { viewer = null } }
    }
}
