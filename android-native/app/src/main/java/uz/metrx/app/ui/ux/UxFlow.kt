package uz.metrx.app.ui.ux

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.Project
import uz.metrx.app.data.Quote
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.report.QuoteMeta
import uz.metrx.app.report.fingerprint
import uz.metrx.app.report.freezeQuote
import uz.metrx.app.report.furniturePages
import uz.metrx.app.report.pdfFile
import uz.metrx.app.report.pdfName
import uz.metrx.app.report.reportMeasurer
import uz.metrx.app.report.snapshotOf
import uz.metrx.app.report.viewLoader
import uz.metrx.app.ui.App
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.furniture.designer
import uz.metrx.app.ui.furniture.drawRoomIn
import uz.metrx.app.ui.furniture.measuredRoom
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.furniture.orderIssues
import uz.metrx.app.ui.furniture.roomKind
import java.io.File
import java.math.BigInteger

/*
 * A furniture order's way from the room to the client (UX upgrades §1, §2, §8; mockup design/ux-upgrades/mockup.html):
 * the five progress steps Xona → Mebel → Dizayn → Narx → PDF (simple mode: "Yuborish"), the one next-step button,
 * the price as the maker sees it, and sending the quote to Telegram, which issues it at once (Undo makes it a draft).
 */

/** A progress step's state. */
enum class StepState { TODO, CUR, DONE, SKIP }

data class FStep(val key: String, val label: String, val state: StepState)

/** The order's five steps: Xona is "–" when the order has no room; the first one not done is the current one. */
fun fSteps(app: App, p: Project): List<FStep> {
    val snap = app.settings.angleSnap
    val furn = p.furniture.isNotEmpty()
    val sent = p.quotes.isNotEmpty()
    val raw = listOf(
        "room" to (if (p.rooms.isEmpty()) StepState.SKIP else if (p.rooms.all { measuredRoom(it, snap) }) StepState.DONE else StepState.TODO),
        "furn" to (if (furn) StepState.DONE else StepState.TODO),
        "design" to (if (furn && (p.designed || sent)) StepState.DONE else StepState.TODO),
        "price" to (if (furn && (p.priced || sent)) StepState.DONE else StepState.TODO),
        "pdf" to (if (sent) StepState.DONE else StepState.TODO)
    )
    val cur = raw.indexOfFirst { it.second == StepState.TODO }
    return raw.mapIndexed { i, (k, s) ->
        FStep(k, app.t(when (k) { "room" -> "ux.st.room"; "furn" -> "ux.st.furn"; "design" -> "ux.st.design"; "price" -> "ux.st.price"
            else -> if (app.settings.advanced) "ux.st.pdf" else "ux.st.send" }), if (i == cur) StepState.CUR else s)
    }
}

/** A tap on a progress step opens its place. */
fun App.openStep(p: Project, key: String) {
    haptic(Hap.TICK)
    when (key) {
        "room" -> {
            val snap = settings.angleSnap
            val r = p.rooms.firstOrNull { !measuredRoom(it, snap) } ?: p.rooms.firstOrNull()
            if (r != null) openRoom(p.id, r.id) else sheet = Sheet.FNewRoom(p.id)
        }
        "furn" -> push(Route.FGallery(p.id))
        "design" -> p.furniture.firstOrNull()?.let { kit.sel = null; push(designer(p.id, it, 2)) } ?: push(Route.FGallery(p.id))
        else -> if (p.furniture.isEmpty()) say("ux.noFurnPrice", kind = ToastKind.INFO) else push(Route.FPrice(p.id))
    }
}

/** The one big button at the bottom of the order: its words, icon and what it does. */
class UxAct(val label: String, val icon: String?, val go: () -> Unit)

/** What to do next with the order (the old NextStep card's logic, now the bottom bar's button). */
fun App.fNextAct(p: Project, ctx: Context): UxAct {
    val lang = settings.lang
    val snap = settings.angleSnap
    val steps = fSteps(this, p)
    val cur = steps.firstOrNull { it.state == StepState.CUR }?.key
    val rooms = p.floors.mapNotNull { w -> p.rooms.firstOrNull { it.floorId == w.id }?.let { w to it } }
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> !measuredRoom(r, snap) }
    val bare = rooms.firstOrNull { (w, r) -> p.furniture.none { it.ws == w.id || it.roomId == r.id } }
    // a measured room with nothing in it and a room-less piece of its kind: the piece goes in
    val loose = bare?.let { (w, r) -> if (measuredRoom(r, snap)) p.furniture.firstOrNull { it.roomId == null && it.kind == roomKind(w) } else null }
    return when (cur) {
        "room" -> when {
            undrawn != null -> UxAct(t("ux.a.drawRoom"), "room") { drawRoomIn(p.id, undrawn, lang) }
            unmeasured != null -> UxAct(t("ux.a.measure"), "ruler") { openRoom(p.id, unmeasured.second.id) }
            else -> UxAct(t("ux.a.addFurn"), "plus") { push(Route.FGallery(p.id)) }
        }
        "furn" -> UxAct(t("ux.a.addFurn"), "plus") { push(Route.FGallery(p.id, bare?.second?.id)) }
        "design" -> if (loose != null && bare != null) UxAct(t("fz.toRoom"), "room") { push(Route.FPlace(p.id, loose.id, bare.second.id)) }
            else UxAct(t("ux.a.design"), "cube") { p.furniture.firstOrNull()?.let { kit.sel = null; push(designer(p.id, it, 2)) } }
        "price" -> UxAct(t("ux.a.price"), "coin") { push(Route.FPrice(p.id)) }
        "pdf" -> UxAct(t("ux.a.tg"), "tg") { sendQuote(ctx, p.id, telegram = true) }
        else -> UxAct(t("ux.a.more"), "plus") { push(Route.FGallery(p.id)) }
    }
}

/* ---------------- the price ---------------- */

/** The order's customer price now (0 with no furniture built). */
fun App.orderPrice(p: Project): BigInteger {
    val s = settings
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    if (fs.isEmpty()) return BigInteger.ZERO
    return priceOf(fs, p.fprice, s.workshop, s.mats, s.hws).price
}

/** "12 345 000 so‘m" in the order's currency. */
fun App.moneyText(p: Project, v: BigInteger): String = moneyStr(v, p.precision, settings.lang == Lang.EN) + " " + curSuffix(p.currency, settings.lang)

/** §4: simple mode's grey "≈ 12 345 000 so‘m (taxminiy)" (to the thousand), Advanced's exact one; null with no price yet. */
fun App.priceWords(p: Project, short: Boolean = false): String? {
    val v = orderPrice(p)
    if (v.signum() <= 0) return null
    if (settings.advanced) return if (short) moneyText(p, v) else t("ux.exact", "v" to moneyText(p, v))
    val r = v.add(BigInteger.valueOf(500)).divide(BigInteger.valueOf(1000)).multiply(BigInteger.valueOf(1000))
    return t(if (short) "ux.approxShort" else "ux.approx", "v" to moneyText(p, r))
}

/* ---------------- issuing and sending the quote ---------------- */

/** The quote that is up to date with the order (its last one, when nothing changed since), else null. */
fun App.currentQuote(p: Project): Quote? {
    val last = p.quotes.lastOrNull() ?: return null
    return if (last.fp == fingerprint(snapshotOf(p, settings))) last else null
}

/**
 * Issues (freezes) the next quote now, with no confirm sheet (§8); an up-to-date one is used again. Null when it can't:
 * no furniture, or the maker's name missing (its sheet opens). [undo] undoes a new quote: it is a draft again.
 */
fun App.issueNow(ctx: Context, pid: String): Pair<Quote, (() -> Unit)?>? {
    val p = store.get(pid) ?: return null
    if (p.furniture.none { it.modules.isNotEmpty() }) { say("ux.noFurnPrice", kind = ToastKind.INFO); return null }
    if (settings.builderName.isBlank()) { sheet = Sheet.Issue(p.id, builderOnly = true); return null }
    currentQuote(p)?.let { return it to null }
    val before = p
    val no = (p.quotes.maxOfOrNull { it.no } ?: 0) + 1
    val q = freezeQuote(ctx, p, snapshotOf(p, settings), no, System.currentTimeMillis())
    val early = p.stage == "measure" || p.stage == "estimate" || p.stage == "design"
    store.update(p.id) { it.copy(quotes = it.quotes + q, stage = if (early) "quote" else it.stage, designed = true, priced = true) }
    return q to {
        store.update(pid) { it.copy(quotes = it.quotes.filter { x -> x.no != q.no }, stage = before.stage) }
        say("ux.backToDraft", kind = ToastKind.INFO)
    }
}

/** Telegram's apps, the main one first (§8); the chooser when none is installed. */
private val TG = listOf("org.telegram.messenger", "org.telegram.messenger.web", "org.thunderdog.challegram")

fun telegramApp(ctx: Context): String? = TG.firstOrNull { pkg -> runCatching { ctx.packageManager.getPackageInfo(pkg, 0) }.isSuccess }

/** Hands the PDF to Telegram ([telegram]) or the phone's share sheet; true when Telegram opened directly. */
fun sharePdfVia(ctx: Context, f: File, title: String, telegram: Boolean): Boolean {
    val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); putExtra(Intent.EXTRA_SUBJECT, f.nameWithoutExtension)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val tg = if (telegram) telegramApp(ctx) else null
    if (tg != null) {
        try { ctx.startActivity(Intent(send).setPackage(tg)); return true } catch (_: ActivityNotFoundException) { } catch (_: SecurityException) { }
    }
    ctx.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    return false
}

/** The issued quote's PDF (prices in, as the client gets it). */
private suspend fun quoteFile(app: App, ctx: Context, q: Quote, name: String): File = withContext(Dispatchers.Default) {
    val pages = furniturePages(reportMeasurer(ctx), q.sn, false, QuoteMeta(q.no, q.ts), viewLoader(ctx), prices = true)
    pdfFile(ctx, pages, pdfName(name, app.t("q.no", "n" to q.no)))
}

/** The draft's PDF, with its draft mark. */
private suspend fun draftFile(app: App, ctx: Context, p: Project): File = withContext(Dispatchers.Default) {
    val sn = snapshotOf(p, app.settings)
    val pages = furniturePages(reportMeasurer(ctx), sn, true, null, viewLoader(ctx), prices = true)
    pdfFile(ctx, pages, pdfName(dn(p.name, app.settings.lang), app.t("es.draft")))
}

/**
 * "Telegram’ga yuborish" ([telegram]) issues the quote at once and opens Telegram with its PDF; a toast offers Undo,
 * which makes it a draft again. "Boshqa…" ([telegram] false) shares the same issued quote through the share sheet.
 */
fun App.sendQuote(ctx: Context, pid: String, telegram: Boolean) {
    if (!once()) return
    val p0 = store.get(pid) ?: return
    // with an error in the Check list, the list first (as the old "Yuborish" did)
    val errs = orderErrors(p0)
    if (errs > 0) { push(Route.FCheck(pid)); say("ux.fixErr", "n" to errs, kind = ToastKind.ERROR); return }
    val (q, undo) = issueNow(ctx, pid) ?: return
    val name = dn(p0.name, settings.lang)
    say("ux.making", kind = ToastKind.INFO)
    scope.launch {
        runCatching { quoteFile(this@sendQuote, ctx, q, name) }
            .onSuccess { f ->
                val direct = runCatching { sharePdfVia(ctx, f, t("sh.title"), telegram) }.getOrDefault(false)
                haptic(Hap.CONFIRM)
                val text = t(if (direct) "ux.sent" else "ux.sentShare", "n" to q.no)
                if (undo != null) act(text, undo) else toast = uz.metrx.app.ui.components.ToastMsg(text)
            }
            .onFailure { undo?.invoke(); say("cm.shareErr", kind = ToastKind.ERROR) }
    }
}

/** "Qoralamani ulashish": the draft's PDF through the share sheet; nothing is issued. */
fun App.shareDraft(ctx: Context, pid: String) {
    if (!once()) return
    val p = store.get(pid) ?: return
    if (p.furniture.none { it.modules.isNotEmpty() }) { say("ux.noFurnPrice", kind = ToastKind.INFO); return }
    say("ux.making", kind = ToastKind.INFO)
    scope.launch {
        runCatching { draftFile(this@shareDraft, ctx, p) }
            .onSuccess { f -> runCatching { sharePdfVia(ctx, f, t("sh.title"), false) } }
            .onFailure { say("cm.shareErr", kind = ToastKind.ERROR) }
    }
}

/** "Taklifni chiqarish": issued now, with Undo instead of the confirm sheet. */
fun App.issueOnly(ctx: Context, pid: String) {
    if (!once()) return
    val (q, undo) = issueNow(ctx, pid) ?: return
    haptic(Hap.CONFIRM)
    if (undo != null) act(t("ux.issuedT", "n" to q.no), undo) else say("ux.issuedT", "n" to q.no)
}

/** The step the bottom bars' "Keyingi: …" names. */
fun App.nextStepName(p: Project): String? = fSteps(this, p).firstOrNull { it.state == StepState.CUR }?.label

/** Errors in the order's Check list (sending waits for them). */
fun App.orderErrors(p: Project): Int = orderIssues(this, p).count { it.level == "err" }
