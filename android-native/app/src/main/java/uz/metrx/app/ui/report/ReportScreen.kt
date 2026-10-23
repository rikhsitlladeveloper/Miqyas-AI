package uz.metrx.app.ui.report

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Phone
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.core.rowsMissing
import uz.metrx.app.core.totals
import uz.metrx.app.data.ViewFiles
import uz.metrx.app.data.dn
import uz.metrx.app.data.fmtDate
import uz.metrx.app.data.itemName
import uz.metrx.app.report.QuoteMeta
import uz.metrx.app.report.RPage
import uz.metrx.app.report.fingerprint
import uz.metrx.app.report.freezeQuote
import uz.metrx.app.report.pageBitmap
import uz.metrx.app.report.pdfFile
import uz.metrx.app.report.pdfName
import uz.metrx.app.report.reportMeasurer
import uz.metrx.app.report.reportPages
import uz.metrx.app.report.sharePdf
import uz.metrx.app.report.snapTotal
import uz.metrx.app.report.snapshotOf
import uz.metrx.app.report.unconfirmed
import uz.metrx.app.report.viewLoader
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigInteger

/*
 * The report (prototype report.js "option A: read it first"): the A4 pages fill the width, swipe between them, tap to
 * zoom; a dark strip keeps the total, page count and language in view; "Set up" holds language, rooms, notes, 3D
 * views and the report's note. A draft can be shared with its DRAFT mark or issued as a frozen quote; an issued quote
 * opens in the same viewer with a lock banner.
 */

private val DARK = Color(0xFF0E1C36)

/** The draft report ([no] null) or issued quote № [no]. */
@Composable
fun ReportScreen(pid: String, no: Int?) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = LocalLang.current
    val p = app.store.get(pid) ?: return
    val quote = no?.let { n -> p.quotes.firstOrNull { it.no == n } } ?: if (no != null) return else null
    // a furniture maker or a tiler in the simple app shares the design: no price, nothing to issue (a tiler's has no estimate)
    val design = quote == null && (p.isFurniture || p.isTiler || p.isElec || p.isPlumb || p.isWin) && !app.settings.advanced
    val sn = quote?.sn ?: snapshotOf(p, app.settings).let { if (design && (p.isTiler || p.isElec || p.isPlumb || p.isWin)) it.copy(pdf = it.pdf.copy(estimate = false)) else it }
    val key = if (quote != null) "q${quote.no}" else (if (design) "d" else "") + fingerprint(sn) + sn.pdf + sn.lang + sn.roomLabel + sn.extras.joinToString { it.text + it.checks }
    val tm = remember { reportMeasurer(ctx) }
    val loader = remember { viewLoader(ctx) }
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    var viewer by remember { mutableStateOf<Int?>(null) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wPx = with(density) { (maxWidth - 32.dp).roundToPx() }
        // a furniture order's quote has its own pages (furniture plan section 10)
        fun layout(): List<RPage> {
            val meta = quote?.let { QuoteMeta(it.no, it.ts) }
            return if (p.isFurniture) uz.metrx.app.report.furniturePages(tm, sn, quote == null, meta, loader, prices = !design) else reportPages(tm, sn, quote == null, meta, loader, design = design)
        }
        // the pages are laid out and drawn away from the screen's thread, again whenever the report changes; each set
        // carries the key it was made for
        val built by produceState<Triple<String, List<RPage>, List<ImageBitmap>>?>(null, key, wPx) {
            value = withContext(Dispatchers.Default) { val pages = layout(); Triple(key, pages, pages.map { pageBitmap(it, wPx) }) }
        }
        val pages = built?.second.orEmpty(); val bmps = built?.third.orEmpty()
        val total = quote?.total?.let { BigInteger(it) } ?: if (p.isFurniture) (sn.ftotal.toBigIntegerOrNull() ?: BigInteger.ZERO) else snapTotal(sn)
        val rl = Lang.of(sn.lang)
        fun share() {
            val b = built ?: return
            app.say("sh.making", kind = ToastKind.INFO)
            val fname = pdfName(dn(quote?.sn?.name ?: p.name, lang), if (quote != null) app.t("q.no", "n" to quote.no) else app.t(if (design) "rpt.design" else "es.draft"))
            // just after a set-up change the pages on screen are the old ones: the PDF is laid out again from the report as it is
            val fresh = b.first == key
            scope.launch {
                runCatching { withContext(Dispatchers.Default) { pdfFile(ctx, if (fresh) b.second else layout(), fname) } }
                    .onSuccess { sharePdf(ctx, it, app.t("sh.title")) }
                    .onFailure { app.say("cm.shareErr", kind = ToastKind.ERROR) }
            }
        }
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(start = 14.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(if (quote != null) tr("q.no", "n" to quote.no) else tr(if (design) "rpt.design" else "rpt.title"), style = ui(17f, 700, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(dn(p.name, lang), style = ui(12.5f, 400, G.ink2, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (quote == null) {
                    val shape = RoundedCornerShape(12.dp)
                    Row(Modifier.heightIn(min = 40.dp).dropShadow(shape, Shadow(20.dp, G.shade.copy(alpha = .08f), offset = DpOffset(0.dp, 8.dp))).clip(shape)
                        .background(G.glass(.55f)).border(1.dp, G.rim, shape).pressable({ app.sheet = Sheet.ReportSetup(p.id) }, .97f)
                        .padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        MIcon("sliders", G.ink, 18.dp, 2f); Text(tr("rp2.setup"), style = ui(14f, 600))
                    }
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (quote == null) {
                    if (app.settings.builderName.isBlank()) Banner("alert", tr("rpt.noBuilder"), amber = true, action = tr("rpt.addBuilder")) { app.sheet = Sheet.Issue(p.id, builderOnly = true) }
                    val uc = unconfirmed(sn)
                    if (uc > 0) Banner("clock", tr("rpt.unconf", "n" to uc), amber = true)
                } else Banner("lock", tr(if (p.isFurniture) "fd.frozen" else "q.frozen") + "\n" + tr("q.issued") + ": " + fmtDate(quote.ts) + " " + fmtTime(quote.ts), amber = false, boldTail = true)
                // the dark strip: total, pages, language
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(DARK).padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        if (design) Text(dn(p.name, lang), style = ui(15f, 700, Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        else {
                            Text(tr("rp2.total"), style = ui(12.5f, 400, Color(0xFFB7C3D9)))
                            Text(moneyStr(total, sn.precision, lang == Lang.EN) + " " + curSuffix(sn.currency, lang), style = ui(22f, 700, Color.White).copy(fontFamily = PlexCond), maxLines = 1)
                        }
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(if (pages.isEmpty()) "…" else tr("rp2.pages", "n" to pages.size), style = ui(12.5f, 400, Color(0xFFB7C3D9)))
                        Text(rl.longName, style = ui(12.5f, 400, Color(0xFFB7C3D9)))
                    }
                }
                val pager = rememberPagerState { bmps.size.coerceAtLeast(1) }
                HorizontalPager(pager, Modifier.fillMaxWidth()) { i ->
                    Box(Modifier.fillMaxWidth().aspectRatio(595f / 842f).dropShadow(RoundedCornerShape(6.dp), Shadow(14.dp, Color(0x24101828), offset = DpOffset(0.dp, 2.dp)))
                        .clip(RoundedCornerShape(6.dp)).background(Color.White)
                        .semantics { contentDescription = app.t("rp2.of", "i" to i + 1, "n" to pages.size) }.clickable(role = Role.Image) { if (bmps.isNotEmpty()) viewer = i }) {
                        bmps.getOrNull(i)?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds) }
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                    NavIb(false, pager.currentPage > 0, tr("rp2.prev")) { scope.launch { pager.animateScrollToPage(pager.currentPage - 1) } }
                    Text(tr("rp2.of", "i" to pager.currentPage + 1, "n" to pages.size.coerceAtLeast(1)), style = ui(14f, 600, G.ink2).copy(fontFamily = PlexCond))
                    NavIb(true, pager.currentPage < pages.size - 1, tr("rp2.next")) { scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } }
                }
                Text(tr("rp2.tapZoom"), style = ui(12.5f, 400, G.ink2), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 0.dp))
            }
            FloatingFooter {
                if (design) GBtn(tr("rpt.share"), { share() }, icon = "share")
                else if (quote == null) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GBtn(tr("rp2.shareDraft"), { share() }, Btn.SECONDARY, icon = "share", modifier = Modifier.weight(1f), maxLines = 2)
                    GBtn(tr("rpt.issue"), {
                        val n = if (p.isFurniture) 0 else rowsMissing(p)
                        if (n > 0) app.say("et.block", "n" to n, kind = ToastKind.ERROR) else app.sheet = Sheet.Issue(p.id)
                    }, icon = "lock", modifier = Modifier.weight(1f), maxLines = 2)
                } else GBtn(tr("rpt.share"), { share() }, icon = "share")
            }
        }
        viewer?.let { start -> PageViewer(pages, start) { viewer = null } }
    }
}

fun fmtTime(ts: Long): String = java.text.SimpleDateFormat("HH:mm", java.util.Locale.ROOT).format(java.util.Date(ts))

@Composable
private fun NavIb(forward: Boolean, on: Boolean, label: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Box(Modifier.size(44.dp).alpha(if (on) 1f else .35f).dropShadow(shape, Shadow(20.dp, G.shade.copy(alpha = .08f), offset = DpOffset(0.dp, 8.dp))).clip(shape)
        .background(G.glass(.55f)).pressable({ if (on) onClick() }, .95f, label = label), contentAlignment = Alignment.Center) {
        MIcon(if (forward) "chev" else "back", G.ink, 18.dp, 2.2f)
    }
}

/** A notice above the pages (prototype .banner warn / lock). */
@Composable
private fun Banner(icon: String, text: String, amber: Boolean, action: String? = null, boldTail: Boolean = false, onAction: () -> Unit = {}) {
    val bg = if (amber) G.amberWash else G.idle(.6f)
    val fg = if (amber) G.amberInk else G.ink
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(bg).border(1.dp, if (amber) Color(0x33EA8C00) else G.idleRim, RoundedCornerShape(14.dp))
        .padding(start = 12.dp, end = 8.dp, top = 10.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        MIcon(icon, fg, 18.dp, 2f)
        if (boldTail && text.contains('\n')) Column(Modifier.weight(1f)) {
            Text(text.substringBefore('\n'), style = ui(13.5f, 400, G.ink, 1.4f)); Text(text.substringAfter('\n'), style = ui(13.5f, 700, G.ink, 1.4f))
        } else Text(text, style = ui(13.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f))
        if (action != null) Text(action, style = ui(13.5f, 700, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClick = onAction).padding(horizontal = 10.dp, vertical = 8.dp))
    }
}

/** All pages one under the other on a dark ground; + shows them at full size (prototype .viewer). */
@Composable
internal fun PageViewer(pages: List<RPage>, start: Int, onClose: () -> Unit) {
    var zoom by rememberSaveable { mutableStateOf(false) }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        BoxWithConstraints(Modifier.fillMaxSize().background(Color(0xF00E1C36))) {
            val density = LocalDensity.current
            val w = if (zoom) 595.dp * 1.6f else maxWidth - 24.dp
            val wPx = with(density) { w.roundToPx() }
            val bmps by produceState<List<ImageBitmap>>(emptyList(), wPx) { value = withContext(Dispatchers.Default) { pages.map { pageBitmap(it, wPx) } } }
            val scroll = rememberScrollState()
            androidx.compose.runtime.LaunchedEffect(bmps.size) {
                if (bmps.isNotEmpty() && !zoom) scroll.scrollTo((with(density) { (w * 842f / 595f + 12.dp).toPx() } * start).toInt())
            }
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                Row(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(tr("sh.pages", "n" to pages.size), style = ui(15f, 700, Color.White), modifier = Modifier.weight(1f))
                    Box(Modifier.size(44.dp, 36.dp).clip(RoundedCornerShape(10.dp)).border(1.dp, Color.White, RoundedCornerShape(10.dp)).clickable(role = Role.Button) { zoom = !zoom },
                        contentAlignment = Alignment.Center) { Text(if (zoom) "−" else "+", style = ui(20f, 600, Color.White)) }
                    Box(Modifier.size(44.dp).clip(RoundedCornerShape(22.dp)).clickable(role = Role.Button, onClick = onClose), contentAlignment = Alignment.Center) { MIcon("x", Color.White, 22.dp, 2f) }
                }
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(scroll).let { if (zoom) it.horizontalScroll(rememberScrollState()) else it }.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    pages.indices.forEach { i ->
                        Box(Modifier.width(w).aspectRatio(595f / 842f).background(Color.White)) { bmps.getOrNull(i)?.let { Image(it, null, Modifier.fillMaxSize()) } }
                    }
                }
            }
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
private fun Chip(on: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(Modifier.heightIn(min = 40.dp).clip(shape).background(if (on) G.cobalt else G.idle(.6f)).border(1.dp, if (on) G.cobalt else G.idleRim, shape)
        .clickable(role = Role.Checkbox, onClick = onClick).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { content() }
}

@Composable
private fun Label(text: String) = Text(text, style = ui(15f, 700))

/** Report language, rooms, notes, 3D views and the report's note (prototype SHEETS.repSetup). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ReportSetupSheet(s: Sheet.ReportSetup) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    var notes by rememberSaveable { mutableStateOf(p.reportNotes) }
    fun keep(v: String) { val now = app.store.get(s.pid) ?: return; if (v != now.reportNotes) app.store.update(now.id, touch = false) { it.copy(reportNotes = v) } }
    fun done() { keep(notes); app.sheet = null }
    // the hardware Back, a tab or the background closes the sheet without done(): the note is kept then too
    val cur by rememberUpdatedState(notes)
    DisposableEffect(Unit) { onDispose { keep(cur) } }
    GlassSheet(tr("rp2.setupTitle"), { done() }, footer = { GBtn(tr("rp2.done"), { done() }) }) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label(tr("rpt.lang"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Lang.entries.forEach { l -> val on = p.reportLang == l.code
                    Chip(on, { app.store.update(p.id, touch = false) { it.copy(reportLang = l.code) } }) { Text(l.longName, style = ui(14f, 600, if (on) Color.White else G.ink)) } }
            }
        }
        if (p.rooms.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label(tr("rpt.rooms"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                p.rooms.forEach { r -> val on = p.reportRooms[r.id] != false
                    Chip(on, { app.store.update(p.id, touch = false) { it.copy(reportRooms = it.reportRooms + (r.id to !on)) } }) {
                        MIcon(if (on) "check" else "plus", if (on) Color.White else G.ink, 14.dp, 2.4f); Text(dn(r.name, lang), style = ui(14f, 600, if (on) Color.White else G.ink))
                    } }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label(tr("rpt.extras"))
            val its = p.floors.flatMap { w -> w.items.map { w to it } }
            if (its.isEmpty()) Text(tr("rpt.noExtras"), style = ui(13.5f, 400, G.ink2))
            else FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                its.forEach { (w, it) -> val on = it.inReport
                    Chip(on, { app.store.update(p.id, touch = false) { pp -> pp.copy(floors = pp.floors.map { f -> if (f.id != w.id) f else f.copy(items = f.items.map { x -> if (x.id == it.id) x.copy(rep = !on) else x }) }) } }) {
                        MIcon(if (on) "check" else "plus", if (on) Color.White else G.ink, 14.dp, 2.4f)
                        MIcon(when (it.kind) { "note" -> "note"; "photo" -> "camera"; else -> "pen" }, if (on) Color.White else G.ink2, 14.dp, 2f)
                        Text(itemName(it, lang), style = ui(14f, 600, if (on) Color.White else G.ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    } }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label(tr("rpt.views"))
            val views = p.rooms.flatMap { it.views }
            // the PDF prints the first four ticked views of the rooms in the report: only those show ticked, and a fifth is refused
            val shown = p.rooms.filter { p.reportRooms[it.id] != false }.flatMap { it.views }.filter { p.reportViews[it.id] != false }.take(4).map { it.id }.toSet()
            if (views.isEmpty()) Text(tr("rpt.noViews"), style = ui(13.5f, 400, G.ink2))
            else Text(tr("3d.inRep", "n" to shown.size), style = ui(13f, 400, G.ink2))
            if (views.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                views.forEach { v -> val on = v.id in shown
                    val bmp by produceState<ImageBitmap?>(null, v.img) { value = withContext(Dispatchers.IO) { ViewFiles.load(ctx, v.img, 240)?.asImageBitmap() } }
                    Box(Modifier.clip(RoundedCornerShape(12.dp)).border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, RoundedCornerShape(12.dp))
                        .clickable(role = Role.Checkbox) {
                            if (!on && shown.size >= 4) app.say("3d.max", kind = ToastKind.ERROR)
                            else app.store.update(p.id, touch = false) { it.copy(reportViews = it.reportViews + (v.id to !on)) }
                        }.padding(4.dp)) {
                        Box(Modifier.size(72.dp, 54.dp).alpha(if (on) 1f else .4f).background(Color.White)) { bmp?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } }
                    }
                }
            }
        }
        GField(tr("rpt.notes"), notes, { notes = it }, placeholder = tr("rpt.notesPh"), optional = true, minLines = 3)
        // the simple furniture app's design has no DRAFT mark
        if (!((p.isFurniture || p.isTiler || p.isElec || p.isPlumb || p.isWin) && !app.settings.advanced)) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("info", G.ink2, 18.dp, 2f); Text(tr("rpt.draftShare"), style = ui(13f, 400, G.ink2, 1.45f), modifier = Modifier.weight(1f))
        }
    }
}

/**
 * Issuing quote №n (prototype SHEETS.issue): first the builder's name and phone when missing, then what gets frozen,
 * the total, language and builder. [Sheet.Issue.builderOnly] asks only for the builder (the report's banner).
 */
@Composable
fun IssueSheet(s: Sheet.Issue) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val no = p.quotes.size + 1
    if (app.settings.builderName.isBlank() || s.builderOnly) {
        var name by rememberSaveable { mutableStateOf(app.settings.builderName) }
        var phone by rememberSaveable { mutableStateOf(app.settings.builderPhone) }
        var tried by remember { mutableStateOf(false) }
        val nameErr = if (name.isBlank()) tr("bd.req") else null
        val phoneErr = Phone.errorKey(phone, true)?.let { tr(it) }
        fun save() {
            if (nameErr != null || phoneErr != null) { tried = true; return }
            app.settings.saveBuilder(name, phone)
            if (s.builderOnly) { app.sheet = null; app.say("bd.saved") } else app.sheet = Sheet.Issue(p.id)
        }
        GlassSheet(if (s.builderOnly) tr("rpt.builder") else tr("iss.title", "n" to no), { app.sheet = null },
            footer = { GBtn(tr(if (s.builderOnly) "common.save" else "iss.saveGo"), { save() }, modifier = Modifier.alpha(if (nameErr != null || phoneErr != null) .5f else 1f)) }) {
            if (!s.builderOnly) Text(tr("iss.needBuilder"), style = ui(15f, 400, G.ink2, 1.45f))
            GField(tr("bd.name"), name, { name = it }, placeholder = tr("fr.namePh"), error = nameErr, showError = tried)
            GField(tr("bd.phone"), phone, { phone = it }, placeholder = "90 123 45 67", phone = true, error = phoneErr, showError = tried, done = false)
        }
        return
    }
    val tt = totals(p)
    // a furniture order's snapshot prices every piece: worked out again only when the order or the settings change
    val fsn = remember(p, app.settings.unit, app.settings.builderName, app.settings.builderPhone, app.settings.pdf, app.settings.angleSnap, app.settings.workshop, app.settings.mats, app.settings.hws) { if (p.isFurniture) snapshotOf(p, app.settings) else null }
    val empty = if (fsn != null) fsn.furniture.isEmpty() else p.estimate.materials.isEmpty() && p.estimate.labor.isEmpty()
    val grand = fsn?.ftotal?.toBigIntegerOrNull() ?: tt.g
    fun issue() {
        if (empty) return
        val now = System.currentTimeMillis()
        val q = freezeQuote(ctx, p, snapshotOf(p, app.settings), no, now)
        app.store.update(p.id) { it.copy(quotes = it.quotes + q) }
        app.sheet = null
        val early = p.stage == "measure" || p.stage == "estimate" || p.stage == "design"
        if (p.isFurniture) {
            // a furniture order: issued from the PDF or the order itself, it moves to "quote sent" and the quote opens, ready to share
            if (app.top is Route.Report) app.pop()
            if (app.top is Route.Project) app.setProjectTab("quotes")
            if (early) app.store.update(p.id) { it.copy(stage = "quote") }
            app.push(Route.Quote(p.id, no))
            app.say(if (early) "fo.issuedMoved" else "iss.done", "n" to no)
            return
        }
        app.pop()
        if (app.top is Route.Project) app.setProjectTab("quotes")
        app.toast = if (early) ToastMsg(app.t("iss.done", "n" to no) + ". " + app.t("bd.stage") + ": " + app.t(if (p.isFurniture) "fs.quote" else "stage.quote") + "?", ToastKind.OK, app.t("bd.move"), onAction = {
            app.store.update(p.id) { it.copy(stage = "quote") }
        }) else ToastMsg(app.t("iss.done", "n" to no))
    }
    GlassSheet(tr("iss.title", "n" to no), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn(tr("common.cancel"), { app.sheet = null }, Btn.SECONDARY, modifier = Modifier.weight(1f))
            GBtn(tr("rpt.issue"), { issue() }, icon = "lock", enabled = !empty, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }) {
        Text(tr(if (p.isFurniture) "fd.issBody" else "iss.body"), style = ui(15f, 400, G.ink2, 1.45f))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp)) {
            Kv(tr("es.grand"), moneyStr(grand, p.precision, lang == Lang.EN) + " " + curSuffix(p.currency, lang), true)
            uz.metrx.app.ui.components.Hairline(); Kv(tr("rpt.lang"), Lang.of(p.reportLang).longName)
            uz.metrx.app.ui.components.Hairline(); Kv(tr(if (p.isFurniture) "fd.maker" else "rpt.builder"), app.settings.builderName)
        }
        if (empty) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.err, 18.dp, 2f); Text(tr(if (p.isFurniture) "fd.empty" else "iss.empty"), style = ui(13.5f, 500, G.err), modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun Kv(k: String, v: String, number: Boolean = false) {
    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(k, style = ui(14f, 400, G.ink2), modifier = Modifier.weight(1f))
        Text(v, style = if (number) ui(15f, 700).copy(fontFamily = PlexCond) else ui(15f, 500), textAlign = TextAlign.End)
    }
}
