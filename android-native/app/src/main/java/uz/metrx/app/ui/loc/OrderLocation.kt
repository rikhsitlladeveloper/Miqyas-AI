package uz.metrx.app.ui.loc

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.app.Activity
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import uz.metrx.app.core.Fix
import uz.metrx.app.core.LocFix
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
 * maker taps "Joylashuvni aniqlash" (no link pasting; how it is read: the GPS section below, fixed 27 Oct 2026); the new-order form's block, the cards' chip with "Yo‘l" or
 * "+ Qo‘shish", the Ma’lumot tab's card and the sheets. The location is never printed in a PDF (report/Snapshot.kt).
 */

/* ---------------- GPS ---------------- */

/**
 * Reading the location from a screen (GPS fix, 27 Oct 2026). [locate] asks for the permission on the first tap (precise
 * and approximate together), shows the system "Turn on location" dialog when location is off, then listens to Google's
 * fused provider (or GPS and network side by side without Google Play services) for up to 30 s: [live] is the best
 * reading so far ("Aniqlik: ±X m"), the search stops by itself at ±20 m, [enough] keeps the current one ("Shu yetarli"),
 * and after 30 s the best one is kept; only with no reading at all does it call back with null. A recent, accurate last
 * known location is the first value ([Fix.cached]), always replaced by a live one.
 *
 * [warmUp] starts listening quietly when the screen opens, if the permission was already given, so the tap is instant;
 * nothing is kept unless the maker taps. [off]: location was off and stays off; [approx]: only approximate location
 * is allowed (Android 12+).
 */
class Gps internal constructor(private val context: Context) {
    var locating by mutableStateOf(false)
        private set
    /** The best reading so far while [locating] (null before the first). */
    var live by mutableStateOf<Fix?>(null)
        private set
    /** The last search ended because location is switched off ("Sozlamalarni ochish"). */
    var off by mutableStateOf(false)
        private set
    /** Only approximate location is allowed (Android 12+): readings are ±1–3 km. */
    var approx by mutableStateOf(false)
        private set
    internal var ask: () -> Unit = {}
    internal var askPrecise: () -> Unit = {}
    internal var resolve: (IntentSender) -> Unit = {}
    internal var result: (Location?) -> Unit = {}

    private val main = Handler(Looper.getMainLooper())
    private var source: LocSource? = null
    /** The best reading since listening began (warm-up included). */
    private var seen: Fix? = null
    /** When the search began (the tap, or the end of the settings check); null while only warming up. */
    private var from: Long? = null
    /** Bumped by every stop, so late answers of the settings check are ignored. */
    private var gen = 0
    private val tick = Runnable { evaluate() }
    private val warmStop = Runnable { if (!locating) stopListening() }

    private fun now() = SystemClock.elapsedRealtime()
    private fun granted(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
    private fun fine() = granted(Manifest.permission.ACCESS_FINE_LOCATION)
    private fun allowed() = fine() || granted(Manifest.permission.ACCESS_COARSE_LOCATION)
    /** Approximate only: Android 12+ lets the maker allow just that. */
    internal fun checkApprox() { approx = Build.VERSION.SDK_INT >= 31 && allowed() && !fine() }

    /** Listens quietly (permission given and location on); stops by itself after [WARM_MS] or when the screen closes. */
    fun warmUp() {
        if (source != null || !allowed() || !locationOn(context)) return
        listen()
        main.removeCallbacks(warmStop); main.postDelayed(warmStop, WARM_MS)
    }

    /** Starts a search; the permission is asked first when it was not given yet (a refusal calls back with null). */
    fun locate() {
        if (locating) return
        locating = true; off = false; live = null
        if (allowed()) { checkApprox(); checkSettings() } else ask()
    }

    /** The permission dialog's answer while locating. */
    internal fun permission(any: Boolean) {
        if (!locating) return
        checkApprox()
        if (any) checkSettings() else finish(null)
    }

    /** Location must be on: Google's settings check shows the "Turn on location" dialog when it can. */
    private fun checkSettings() {
        val g = gen
        // location on: search at once (Google's check would also fail on its "Location Accuracy" switch and ask on
        // every tap); off: Google's dialog, or without Google Play services the message with "Sozlamalarni ochish"
        if (locationOn(context)) { search(); return }
        if (!hasPlayServices(context)) { turnedOff(); return }
        runCatching {
            LocationServices.getSettingsClient(context).checkLocationSettings(LocationSettingsRequest.Builder().addLocationRequest(highAccuracyRequest()).build())
                .addOnSuccessListener { if (g == gen && locating) search() }
                .addOnFailureListener { e ->
                    if (g != gen || !locating) return@addOnFailureListener
                    when {
                        locationOn(context) -> search()
                        e is ResolvableApiException -> runCatching { resolve(e.resolution.intentSender) }.onFailure { resolved(false) }
                        else -> turnedOff()
                    }
                }
        }.onFailure { if (locationOn(context)) search() else turnedOff() }
    }

    /** The "Turn on location" dialog's answer: accepted, search at once; refused, search anyway if location is on. */
    internal fun resolved(ok: Boolean) {
        if (!locating) return
        if (ok || locationOn(context)) search() else turnedOff()
    }

    private fun turnedOff() { off = true; finish(null) }

    private fun search() {
        from = now()
        main.removeCallbacks(warmStop)
        seen = seen?.takeIf { usable(it) }
        if (source == null) listen()
        live = seen
        evaluate()
    }

    /** A reading still worth showing: a cached one under the cache rules, a live one younger than the same 2 min. */
    private fun usable(f: Fix) = if (f.cached) LocFix.freshEnough(f, now()) else now() - f.atMs < LocFix.CACHE_AGE_MS

    private fun listen() {
        val s: LocSource = if (hasPlayServices(context)) FusedSource(context) else PlatformSource(context)
        source = s
        s.start(::onFix) {
            if (source !== s) return@start
            // the fused provider failed: the phone's own providers; they failed too: no readings (30 s, then null)
            if (s is FusedSource) { val p = PlatformSource(context); source = p; p.start(::onFix) { if (source === p) source = null } }
            else source = null
        }
    }

    private fun onFix(f: Fix) {
        if (!usable(f)) return
        seen = LocFix.better(seen?.takeIf { usable(it) }, f)
        if (locating && from != null) { live = seen; evaluate() }
    }

    private fun evaluate() {
        val start = from ?: return
        if (!locating) return
        main.removeCallbacks(tick)
        when (LocFix.step(seen, now() - start, precise = fine())) {
            LocFix.Step.DONE -> finish(seen)
            LocFix.Step.FAIL -> finish(null)
            LocFix.Step.WAIT -> main.postDelayed(tick, 500L)
        }
    }

    /** "Shu yetarli": keeps the current reading. */
    fun enough() { if (locating && from != null) seen?.let { finish(it) } }

    private fun finish(f: Fix?) {
        stop()
        result(f?.let { Location(it.lat, it.lng, LocFix.metres(it.acc), System.currentTimeMillis()) })
    }

    private fun stop() {
        locating = false; from = null; live = null; gen++
        main.removeCallbacks(tick)
        stopListening()
    }

    private fun stopListening() { main.removeCallbacks(warmStop); source?.stop(); source = null; seen = null }

    /** Stops a search (and the warm-up) that is running; nothing is called back. */
    fun cancel() = stop()

    /** Back from the app settings: the permission may have changed. */
    internal fun resumed() { if (approx) checkApprox() }

    /** "Qayta so‘rash": asks for precise location again (approximate only). */
    fun askAgain() = askPrecise()

    private companion object { const val WARM_MS = 180_000L }
}

/** Opens the phone's location settings (location switched off). */
fun openLocationSettings(ctx: Context) {
    runCatching { ctx.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)) }.onFailure { runCatching { ctx.startActivity(Intent(Settings.ACTION_SETTINGS)) } }
}

/** Opens METRX's page in the phone's settings (permissions). */
fun openAppSettings(ctx: Context) {
    runCatching { ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null))) }
}

/**
 * The screen's [Gps]: [warm] starts listening quietly when the screen opens (permission already given), and everything
 * stops when it closes.
 */
@Composable
fun rememberGps(warm: Boolean = false, onResult: (Location?) -> Unit): Gps {
    val ctx = LocalContext.current
    val gps = remember { Gps(ctx) }
    val cb by rememberUpdatedState(onResult)
    gps.result = { cb(it) }
    val perms = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res -> gps.permission(res.values.any { it }) }
    val again = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { gps.checkApprox() }
    val turnOn = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { r -> gps.resolved(r.resultCode == Activity.RESULT_OK) }
    gps.ask = { launcher.launch(perms) }
    gps.askPrecise = { again.launch(perms) }
    gps.resolve = { s -> turnOn.launch(IntentSenderRequest.Builder(s).build()) }
    val life = LocalLifecycleOwner.current
    DisposableEffect(gps, life) {
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_RESUME) gps.resumed() }
        life.lifecycle.addObserver(obs)
        if (warm) gps.warmUp()
        onDispose { life.lifecycle.removeObserver(obs); gps.cancel() }
    }
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
            // "GPS · 24.10" (mockup pinRow: where and when it was read)
            val day = remember(l.ts) { if (l.ts > 0) java.text.SimpleDateFormat("dd.MM", java.util.Locale.ROOT).format(java.util.Date(l.ts)) else "" }
            Text(if (day.isEmpty()) tr("loc.src") else tr("loc.srcD", "d" to day), style = ui(12f, 400, G.ink2))
        }
    }
}

/**
 * "Joylashuv aniqlanmoqda…" with a spinner and "Bekor"; once there is a reading, its live "Aniqlik: ±X m" (the last
 * known location labelled as such) and "Shu yetarli", which keeps it.
 */
@Composable
fun WaitRow(gps: Gps, onCancel: () -> Unit) {
    val f = gps.live
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.blueWash).padding(start = 12.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(24.dp), color = G.cobalt, strokeWidth = 2.6.dp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(tr("loc.wait"), style = ui(14.5f, 700))
                if (f == null) Text(tr("loc.waitS"), style = ui(12f, 400, G.ink2))
                else Text(tr(if (f.cached) "loc.liveC" else "loc.live", "m" to LocFix.metres(f.acc)), style = ui(12.5f, 700, if (f.cached) G.ink2 else G.cobalt2))
            }
            Text(tr("loc.cancel"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp))
                .clickable(role = Role.Button, onClick = onCancel).padding(horizontal = 12.dp, vertical = 12.dp))
        }
        if (f != null) SmallBtn(tr("loc.enough"), "check", Modifier.fillMaxWidth().padding(end = 6.dp), G.cobalt2) { gps.enough() }
    }
}

/**
 * "Joylashuvni aniqlab bo‘lmadi" with the hint about the permission and GPS; when location is switched off
 * ([Gps.off]), "Joylashuv o‘chiq" with "Sozlamalarni ochish".
 */
@Composable
fun FailRow(gps: Gps? = null) {
    val off = gps?.off == true
    val ctx = LocalContext.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.errWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PathIcon(WARN, G.err, 22.dp, 2f)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(tr(if (off) "loc.offT" else "loc.failT"), style = ui(14.5f, 700))
                Text(tr(if (off) "loc.offB" else "loc.failB"), style = ui(12.5f, 400, G.ink2, 1.4f))
            }
        }
        if (off) SmallBtn(tr("loc.settings"), "sliders", Modifier.fillMaxWidth()) { openLocationSettings(ctx) }
    }
}

/** "Aniq joylashuv o‘chiq — taxminiy (±1–3 km)" with "Qayta so‘rash" and "Sozlamalarni ochish" (approximate only, Android 12+). */
@Composable
fun ApproxNote(gps: Gps) {
    if (!gps.approx) return
    val ctx = LocalContext.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.amberWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            PathIcon(WARN, G.amberInk, 18.dp, 2f)
            Text(tr("loc.approx"), style = ui(12.5f, 600, G.amberInk, 1.35f), modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallBtn(tr("loc.askAgain"), null, Modifier.weight(1f)) { gps.askAgain() }
            SmallBtn(tr("loc.settings"), null, Modifier.weight(1f)) { openAppSettings(ctx) }
        }
    }
}

/** A small white button inside a coloured row ("Shu yetarli", "Sozlamalarni ochish", "Qayta so‘rash"). */
@Composable
private fun SmallBtn(label: String, icon: String?, modifier: Modifier = Modifier, fg: Color = G.ink, onClick: () -> Unit) {
    Row(modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.85f)).clickable(role = Role.Button, onClick = onClick)
        .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        if (icon != null) MIcon(icon, fg, 18.dp, 2.2f)
        Text(label, style = ui(14f, 700, fg), maxLines = 2, textAlign = TextAlign.Center)
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
            LocState.LOCATING -> WaitRow(gps) { gps.cancel(); onState(LocState.NONE) }
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
                FailRow(gps)
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
        if (state != LocState.SKIP) ApproxNote(gps)
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
    // listens quietly from the moment the sheet opens (permission already given), so the tap is instant
    val gps = rememberGps(warm = true) { l ->
        if (l != null) { app.sheet = null; app.haptic(Hap.CONFIRM); app.setOrderLocation(pid, l) }
        else { failed = true; app.haptic(Hap.WARN) }
    }
    val sub = listOf(dn(p.customer, lang).ifBlank { dn(p.name, lang) }, dn(p.address, lang)).filter { it.isNotBlank() }.joinToString(" · ")
    GlassSheet(tr(if (p.location != null) "loc.changeT" else "loc.addT"), { gps.cancel(); app.sheet = null }) {
        if (sub.isNotEmpty()) Text(sub, style = ui(13f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
        fun locate() { app.haptic(Hap.TICK); failed = false; gps.locate() }
        when {
            gps.locating -> WaitRow(gps) { gps.cancel() }
            failed -> {
                FailRow(gps)
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
        ApproxNote(gps)
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
