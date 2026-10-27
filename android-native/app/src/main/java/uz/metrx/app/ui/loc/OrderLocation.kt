package uz.metrx.app.ui.loc

import android.Manifest
import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import uz.metrx.app.core.MapLinks
import uz.metrx.app.data.Location
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap

/*
 * An order's location, for every trade (room-shapes build spec §1, approved 26 Oct 2026): GPS only, read when the
 * maker taps "Joylashuvni aniqlash" (no link pasting); the new-order form's block, the cards' chip with "Yo‘l" or
 * "+ Qo‘shish", the Ma’lumot tab's card and the sheets. The location is never printed in a PDF (report/Snapshot.kt).
 */

/* ---------------- GPS ---------------- */

/**
 * One GPS fix (GPS works without internet). Calls back with null when location is off or the phone can't get a fix
 * within 15 s (then the last known one, if any). Returns a function that cancels it without calling back.
 */
@SuppressLint("MissingPermission")
fun currentLocation(context: Context, done: (Location?) -> Unit): () -> Unit {
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    val provider = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).firstOrNull { runCatching { lm.isProviderEnabled(it) }.getOrDefault(false) }
    if (provider == null) { done(null); return {} }
    val main = Handler(Looper.getMainLooper())
    val signal = CancellationSignal()
    var finished = false
    var listener: LocationListener? = null
    lateinit var timeout: Runnable
    fun finish(l: android.location.Location?) {
        if (finished) return; finished = true
        main.removeCallbacks(timeout)
        listener?.let { runCatching { lm.removeUpdates(it) } }
        done(l?.let { Location(it.latitude, it.longitude, maxOf(1, it.accuracy.toInt()), System.currentTimeMillis()) })
    }
    timeout = Runnable { finish(runCatching { lm.getLastKnownLocation(provider) }.getOrNull()) }
    main.postDelayed(timeout, 15000)
    runCatching {
        if (Build.VERSION.SDK_INT >= 30) lm.getCurrentLocation(provider, signal, ContextCompat.getMainExecutor(context)) { finish(it) }
        else {
            // all four methods, as older Androids call them all
            val li = object : LocationListener {
                override fun onLocationChanged(location: android.location.Location) = finish(location)
                @Deprecated("Deprecated in Java") override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) = finish(null)
            }
            listener = li
            @Suppress("DEPRECATION") lm.requestSingleUpdate(provider, li, Looper.getMainLooper())
        }
    }.onFailure { finish(null) }
    return {
        if (!finished) {
            finished = true
            main.removeCallbacks(timeout)
            runCatching { signal.cancel() }
            listener?.let { runCatching { lm.removeUpdates(it) } }
        }
    }
}

/** Reading the GPS from a screen: asks for the permission on the first tap; [locating] while it runs. */
class Gps internal constructor(private val context: Context) {
    var locating by mutableStateOf(false)
        private set
    internal var ask: () -> Unit = {}
    internal var result: (Location?) -> Unit = {}
    private var stop: (() -> Unit)? = null

    private fun allowed() = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** Starts a fix; the permission is asked first when it was not given yet (a refusal calls back with null). */
    fun locate() {
        if (locating) return
        locating = true
        if (allowed()) start() else ask()
    }

    internal fun start() {
        locating = true
        stop = currentLocation(context) { l -> stop = null; locating = false; result(l) }
    }

    internal fun refused() { locating = false; result(null) }

    /** Stops a fix that is running; nothing is called back. */
    fun cancel() { stop?.invoke(); stop = null; locating = false }
}

@Composable
fun rememberGps(onResult: (Location?) -> Unit): Gps {
    val ctx = LocalContext.current
    val gps = remember { Gps(ctx) }
    val cb by rememberUpdatedState(onResult)
    gps.result = { cb(it) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        if (res.values.any { it }) gps.start() else gps.refused()
    }
    gps.ask = { launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)) }
    DisposableEffect(gps) { onDispose { gps.cancel() } }
    return gps
}

/* ---------------- small parts ---------------- */

private const val NAV = "M3.5 10.5L20 4l-6.5 16.5-2.2-7.3z"
private const val GPS_IC = "M5 12a7 7 0 1 0 14 0a7 7 0 1 0 -14 0z M9.5 12a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0z M12 2v3M12 19v3M2 12h3M19 12h3"
private const val WARN = "M12 3.5l9 16H3z M12 10v4M12 17h.01"

private val greenInk @Composable get() = if (Theme.dark) G.green else Color(0xFF15803D)

/** The pin with its coordinates, "±N m" and where it came from (mockup pinRow). */
@Composable
fun PinRow(l: Location) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.greenWash).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.85f)), contentAlignment = Alignment.Center) { MIcon("pin", greenInk, 20.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(MapLinks.coords(l.lat, l.lng), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Text(tr("loc.acc", "m" to l.acc), style = ui(11.5f, 800, greenInk), maxLines = 1,
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(G.glass(.85f)).padding(horizontal = 7.dp, vertical = 2.dp))
            }
            Text(tr("loc.src"), style = ui(12f, 400, G.ink2))
        }
    }
}

/** "Joylashuv aniqlanmoqda…" with a spinner and "Bekor". */
@Composable
fun WaitRow(onCancel: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.blueWash).padding(start = 12.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(24.dp), color = G.cobalt, strokeWidth = 2.6.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("loc.wait"), style = ui(14.5f, 700))
            Text(tr("loc.waitS"), style = ui(12f, 400, G.ink2))
        }
        Text(tr("loc.cancel"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onCancel).padding(horizontal = 12.dp, vertical = 12.dp))
    }
}

/** "Joylashuvni aniqlab bo‘lmadi" with the hint about the permission and GPS. */
@Composable
fun FailRow() {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.errWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        PathIcon(WARN, G.err, 22.dp, 2f)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("loc.failT"), style = ui(14.5f, 700))
            Text(tr("loc.failB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        }
    }
}

/** The big "Joylashuvni aniqlash" button. */
@Composable
fun GpsButton(onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(G.cobalt.copy(alpha = .1f)).border(1.dp, G.cobalt.copy(alpha = .22f), shape)
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
        PathIcon(GPS_IC, G.cobalt2, 22.dp, 2f)
        Text(tr("loc.get"), style = ui(15.5f, 700, G.cobalt2), textAlign = TextAlign.Center)
    }
}

/** A grey half-width button ("Qayta aniqlash", "Olib tashlash"…); [danger] red. */
@Composable
private fun RowScope.Btn2(label: String, onClick: () -> Unit, icon: String? = null, gps: Boolean = false, danger: Boolean = false) {
    val fg = if (danger) G.err else G.ink
    Row(Modifier.weight(1f).heightIn(min = 46.dp).clip(RoundedCornerShape(14.dp)).background(if (danger) G.errWash else G.ink.copy(alpha = .06f))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        if (gps) PathIcon(GPS_IC, fg, 18.dp, 2f) else if (icon != null) MIcon(icon, fg, 18.dp, 2f)
        Text(label, style = ui(14f, 700, fg), maxLines = 2, textAlign = TextAlign.Center)
    }
}

/** The chip: green "Joylashuv bor" or muted "Joylashuv yo‘q". */
@Composable
fun LocChip(has: Boolean) {
    val fg = if (has) greenInk else G.ink2
    Row(Modifier.heightIn(min = 32.dp).clip(RoundedCornerShape(16.dp)).background(if (has) G.greenWash else G.ink.copy(alpha = .07f)).padding(horizontal = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        MIcon("pin", fg, 15.dp, 2.2f)
        Text(tr(if (has) "loc.has" else "loc.no"), style = ui(12.5f, 700, fg), maxLines = 1)
    }
}

/** "+ Qo‘shish": opens the sheet with the GPS button. */
@Composable
fun AddLocLink(onClick: () -> Unit) {
    Text(tr("loc.add"), style = ui(12.5f, 800, G.cobalt2), maxLines = 1,
        modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(16.dp)).clickable(role = Role.Button, onClickLabel = tr("loc.addA"), onClick = onClick)
            .padding(vertical = 6.dp).clip(RoundedCornerShape(16.dp)).background(G.blueWash).padding(horizontal = 11.dp, vertical = 7.dp))
}

/** The blue "Yo‘l" button. */
@Composable
fun YolButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(14.dp)).background(G.cobalt).clickable(role = Role.Button, onClickLabel = tr("loc.yolA"), onClick = onClick)
        .padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        PathIcon(NAV, Color.White, 18.dp, 2.2f)
        Text(tr("loc.yol"), style = ui(14.5f, 800, Color.White), maxLines = 1)
    }
}

/* ---------------- the new-order form ---------------- */

/** The form's location state: none, locating, ok, fail or skip (mockup locBlock). */
object LocState { const val NONE = "none"; const val LOCATING = "locating"; const val OK = "ok"; const val FAIL = "fail"; const val SKIP = "skip" }

/**
 * The "Joylashuv" block under the address of the new-order form, shared by every trade. [state] and [loc] live in the
 * form; [gps] reads the fix (the form sets "ok" or "fail" when it answers).
 */
@Composable
fun LocFormBlock(state: String, loc: Location?, gps: Gps, onState: (String) -> Unit, onLoc: (Location?) -> Unit) {
    val app = LocalApp.current
    fun locate() { app.haptic(Hap.TICK); onState(LocState.LOCATING); gps.locate() }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("pin", G.cobalt, 18.dp, 2.2f)
            Text(tr("np.location"), style = ui(15f, 800))
            Text(tr("loc.optPdf"), style = ui(12f, 500, G.ink3), modifier = Modifier.weight(1f), textAlign = TextAlign.End, maxLines = 2)
        }
        when (state) {
            LocState.LOCATING -> WaitRow { gps.cancel(); onState(LocState.NONE) }
            LocState.OK -> if (loc != null) {
                PinRow(loc)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Btn2(tr("loc.again"), ::locate, gps = true)
                    Btn2(tr("loc.remove"), {
                        val prev = loc
                        onLoc(null); onState(LocState.NONE)
                        app.say("loc.removed", kind = ToastKind.INFO, action = "common.undo") { onLoc(prev); onState(LocState.OK) }
                    }, icon = "trash", danger = true)
                }
            }
            LocState.FAIL -> {
                FailRow()
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Btn2(tr("loc.retry"), ::locate, gps = true) }
                Later { onState(LocState.SKIP) }
            }
            LocState.SKIP -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LocChip(false)
                Text(tr("loc.skipped"), style = ui(12.5f, 400, G.ink2), modifier = Modifier.weight(1f))
                AddLocLink { onState(LocState.NONE) }
            }
            else -> {
                GpsButton(::locate)
                Text(tr("loc.hint"), style = ui(12.5f, 400, G.ink2, 1.4f))
                Later { app.haptic(Hap.TICK); onState(LocState.SKIP); onLoc(null) }
            }
        }
    }
}

@Composable
private fun Later(onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Text(tr("loc.later"), style = ui(14f, 700, G.ink2).copy(textDecoration = TextDecoration.Underline),
            modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp, vertical = 12.dp))
    }
}

/* ---------------- order cards and the Ma’lumot tab ---------------- */

/** The order card's line: "Joylashuv bor" with "Yo‘l", or "Joylashuv yo‘q" with "+ Qo‘shish". */
@Composable
fun OrderLocRow(p: Project, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        LocChip(p.location != null)
        if (p.location == null) AddLocLink { app.sheet = Sheet.LocAdd(p.id) }
        Box(Modifier.weight(1f))
        if (p.location != null) YolButton({ app.sheet = Sheet.Yol(p.id) })
    }
}

/** The Ma’lumot tab's location card: the pin, "±N m", Yo‘l and O‘zgartirish; or "Joylashuv yo‘q · + Qo‘shish". No live map. */
@Composable
fun LocInfoCard(p: Project) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tr("pr.location"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(tr("loc.noPdf"), style = ui(12f, 500, G.ink3))
        }
        val l = p.location
        if (l != null) {
            PinRow(l)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                YolButton({ app.sheet = Sheet.Yol(p.id) }, Modifier.weight(1f))
                Btn2(tr("loc.change"), { app.sheet = Sheet.LocAdd(p.id) }, icon = "edit")
            }
        } else Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LocChip(false)
            Box(Modifier.weight(1f))
            AddLocLink { app.sheet = Sheet.LocAdd(p.id) }
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun LocSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.LocAdd -> LocAddSheet(s.pid)
        is Sheet.Yol -> YolSheet(s.pid)
        else -> return false
    }
    return true
}

/** Sets the order's location (null: removes it) with a toast and Undo. */
fun App.setOrderLocation(pid: String, l: Location?) {
    val prev = store.get(pid)?.location ?: if (l == null) return else null
    store.update(pid) { it.copy(location = l) }
    val text = when { l == null -> t("loc.removed"); prev != null -> t("loc.updated", "m" to l.acc); else -> t("loc.added", "m" to l.acc) }
    act(text, { store.update(pid) { it.copy(location = prev) } })
}

@Composable
private fun LocAddSheet(pid: String) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    var failed by remember { mutableStateOf(false) }
    val gps = rememberGps { l ->
        if (l != null) { app.sheet = null; app.haptic(Hap.CONFIRM); app.setOrderLocation(pid, l) }
        else { failed = true; app.haptic(Hap.WARN) }
    }
    val sub = listOf(dn(p.customer, lang).ifBlank { dn(p.name, lang) }, dn(p.address, lang)).filter { it.isNotBlank() }.joinToString(" · ")
    GlassSheet(tr(if (p.location != null) "loc.changeT" else "loc.addT"), { gps.cancel(); app.sheet = null }) {
        if (sub.isNotEmpty()) Text(sub, style = ui(13f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
        fun locate() { app.haptic(Hap.TICK); failed = false; gps.locate() }
        when {
            gps.locating -> WaitRow { gps.cancel() }
            failed -> {
                FailRow()
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Btn2(tr("loc.retry"), ::locate, gps = true) }
            }
            else -> {
                p.location?.let { PinRow(it) }
                GpsButton(::locate)
                Text(tr("loc.sheetHint"), style = ui(12.5f, 400, G.ink2, 1.4f))
                if (p.location != null) Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text(tr("loc.del"), style = ui(14f, 700, G.err), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp))
                        .clickable(role = Role.Button) { app.sheet = null; app.setOrderLocation(pid, null) }.padding(horizontal = 14.dp, vertical = 12.dp))
                }
            }
        }
    }
}

private fun installed(ctx: Context, pkg: String): Boolean = runCatching { ctx.packageManager.getPackageInfo(pkg, 0); true }.getOrDefault(false)

/** Opens [l] in map app [a], or its https map when the app is missing (or refuses the link). */
fun openIn(ctx: Context, a: MapLinks.App, l: Location): Boolean {
    val o = MapLinks.open(a, l.lat, l.lng) { installed(ctx, it) }
    fun start(uri: String, pkg: String?) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)).also { i -> pkg?.let { i.setPackage(it) } }); true }.getOrDefault(false)
    return start(o.uri, o.pkg) || (o.pkg != null && start(MapLinks.webLink(a, l.lat, l.lng), null))
}

/** One row of the Yo‘l sheet: its strings key, colour and mark, and the map app ([app] null: copy the coordinates). */
private class Opt(val key: String, val color: Color, val letter: String?, val icon: String?, val app: MapLinks.App?)

@Composable
private fun YolSheet(pid: String) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ctx = LocalContext.current
    val p = app.store.get(pid)
    val l = p?.location ?: run { app.sheet = null; return }
    val who = dn(p.customer, lang).ifBlank { dn(p.name, lang) }
    GlassSheet(tr("loc.yol"), { app.sheet = null }) {
        Text(listOf(who, MapLinks.coords(l.lat, l.lng)).filter { it.isNotBlank() }.joinToString(" · "), style = ui(13f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
        listOf(
            Opt("ym", Color(0xFFFC3F1D), "Y", null, MapLinks.App.YANDEX_MAPS),
            Opt("yn", Color(0xFF6E4BF2), null, NAV, MapLinks.App.YANDEX_NAVI),
            Opt("gm", Color(0xFF34A853), "G", null, MapLinks.App.GOOGLE_MAPS),
            Opt("copy", Color(0xFF64748B), null, null, null)
        ).forEach { o ->
            val there = o.app == null || installed(ctx, o.app.pkg)
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp))
                .clickable(role = Role.Button) {
                    app.haptic(Hap.TICK)
                    if (o.app == null) {
                        val c = MapLinks.coords(l.lat, l.lng)
                        runCatching { ctx.getSystemService(ClipboardManager::class.java)?.setPrimaryClip(ClipData.newPlainText("METRX", c)) }
                        app.sheet = null; app.say("loc.copied", "c" to c)
                    } else {
                        app.sheet = null
                        if (!openIn(ctx, o.app, l)) app.say("loc.noApp", kind = ToastKind.ERROR)
                    }
                }.padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(o.color), contentAlignment = Alignment.Center) {
                    when { o.letter != null -> Text(o.letter, style = ui(18f, 800, Color.White)); o.icon != null -> PathIcon(o.icon, Color.White, 20.dp, 2.2f); else -> MIcon("copy", Color.White, 20.dp, 2f) }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(tr("loc.${o.key}"), style = ui(15f, 700))
                    Text(if (there) tr("loc.${o.key}S") else tr("loc.web"), style = ui(12.5f, 400, G.ink2), maxLines = 2)
                }
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
        }
        Text(tr("loc.only"), style = ui(12.5f, 400, G.ink2, 1.4f), modifier = Modifier.widthIn(max = 520.dp))
    }
}
