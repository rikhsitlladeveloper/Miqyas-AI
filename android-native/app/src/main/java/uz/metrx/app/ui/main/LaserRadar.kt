package uz.metrx.app.ui.main

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.State
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.laser.LaserFail
import uz.metrx.app.laser.LaserLog
import uz.metrx.app.laser.LaserPerms
import uz.metrx.app.laser.LaserReading
import uz.metrx.app.laser.Link
import uz.metrx.app.laser.LinkRules
import uz.metrx.app.laser.RadarMath
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.mono
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * The laser radar (approved 24 Oct 2026; mockups laser-radar, laser-connect-anim variant A, laser-connect-fail):
 * a full page that finds the ZB-08 and connects it. The phone is the blue disc in the middle, rings pulse out from it,
 * a sweep turns; every laser the scan hears ("ZB…" or the SPS service) is a bubble at a fixed angle for its address and
 * as near the middle as its signal is strong (−45 dBm near … −90 dBm at the edge). Other Bluetooth devices are behind
 * a link. Tapping a laser connects it: the radar stops and a dashed beam with dots flowing both ways joins the two
 * until the link is ready; then the laser glides into the middle, the middle turns green with a check, the phone gives
 * one soft buzz and the next real measurement shows in a box. A failure snaps the beam, shakes the laser, turns the
 * middle orange (fixable) or red (not a laser) and buzzes twice, with a card saying what to do.
 *
 * The connection itself is RealLaser's (unchanged rules, plus the reasons it now tells: laser/LinkRules.kt). While this
 * page is open, measurements come here first (LaserRouter.radarTake), the "connected"/"lost" toasts are left out, a lost
 * link counts down 4 s here before the app connects again, and background tries wait at most that long.
 */

private enum class RMode { NO_BT, OFF, PERM, DENIED, LOC_OFF, SEARCH, NONE, FOUND, SAVED, CONNECTING, CONNECTED, FAILED, LOST }

private enum class Tone { COBALT, WARN, BAD, OFF, OK }

/** The mockups' colours that G has no name for (light, dark). */
private object RC {
    val warn get() = if (Theme.dark) Color(0xFFFBBF24) else Color(0xFFD97706)
    val warnSoft get() = warn.copy(alpha = if (Theme.dark) .18f else .14f)
    val warnBg get() = if (Theme.dark) G.amberWash else Color(0xFFFFF4E5)
    val bad get() = if (Theme.dark) Color(0xFFF87171) else Color(0xFFDC2626)
    val badSoft get() = bad.copy(alpha = if (Theme.dark) .16f else .12f)
    val off get() = if (Theme.dark) Color(0xFF56627A) else Color(0xFF94A3B8)
    val okSoft get() = G.green.copy(alpha = if (Theme.dark) .16f else .12f)
    val cobaltSoft get() = G.cobalt.copy(alpha = if (Theme.dark) .18f else .12f)
    val hair get() = G.ink.copy(alpha = if (Theme.dark) .09f else .08f)
    val screen get() = if (Theme.dark) Color(0xFF0F1424) else Color(0xFFF4F6FC)
    fun of(t: Tone) = when (t) { Tone.COBALT -> G.cobalt; Tone.WARN -> warn; Tone.BAD -> bad; Tone.OFF -> off; Tone.OK -> G.green }
    fun soft(t: Tone) = when (t) { Tone.WARN -> warnSoft; Tone.BAD -> badSoft; Tone.OK -> okSoft; else -> cobaltSoft }
}

/** The mockups' icons (24 × 24 SVG paths). */
private object RI {
    const val PHONE = "M9 2.5h6a2.5 2.5 0 0 1 2.5 2.5v14a2.5 2.5 0 0 1 -2.5 2.5h-6a2.5 2.5 0 0 1 -2.5 -2.5v-14a2.5 2.5 0 0 1 2.5 -2.5zM10.5 18.5h3"
    const val CHECK = "M5 12.5l4.5 4.5L19 7"
    const val BANG = "M12 6v8M12 18.5v.01"
    const val X = "M7 7l10 10M17 7L7 17"
    const val LOCK = "M7 11h10a2 2 0 0 1 2 2v5a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-5a2 2 0 0 1 2 -2zM8 11V8a4 4 0 0 1 8 0v3"
    const val BTOFF = "M7 7l10 10-5 5V2l5 5-4 4M3 3l18 18"
    const val BT = "M7 7l10 10-5 5V2l5 5L7 17"
    const val SHIELD = "M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6zM12 9v4M12 16v.01"
    const val SYNC = "M20 12a8 8 0 0 1 -14 5.3M4 12a8 8 0 0 1 14 -5.3M18 3v4h-4M6 21v-4h4"
    const val HELP = "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0zM9.5 9.5a2.5 2.5 0 1 1 4 2c-.9.6-1.5 1-1.5 2M12 17v.01"
    const val INFO = "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0zM12 8v5M12 16.5v.01"
    const val LASER = "M5 7h8a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2v-6a2 2 0 0 1 2 -2zM15 12h6M6.5 10.5h3M7.5 14v.01"
    const val PIN = "M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11zM12 12.5a2.5 2.5 0 1 0 0-5a2.5 2.5 0 1 0 0 5z"
}

/** A laser on the radar (immutable: a bubble whose laser did not change is not drawn again). */
@Immutable
private data class Bub(val addr: String, val name: String, val rssi: Int, val avg: Float, val saved: Boolean = false, val tone: Tone = Tone.COBALT,
                       val badge: String? = null, val dim: Boolean = false, val sig: Boolean = false, val sigText: String? = null)

/** The phone's "remove animations" switch (animator duration scale 0): glides and loops are left out. */
internal fun reducedMotion(ctx: Context) = try {
    android.provider.Settings.Global.getFloat(ctx.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
} catch (_: Exception) { false }

/** One soft buzz when connected, two short ones on a failure. */
private fun buzz(ctx: Context, twice: Boolean) {
    val v: Vibrator? = if (Build.VERSION.SDK_INT >= 31) ctx.getSystemService(VibratorManager::class.java)?.defaultVibrator
        else @Suppress("DEPRECATION") ctx.getSystemService(Vibrator::class.java)
    if (v == null || !v.hasVibrator()) return
    try {
        v.vibrate(
            if (twice) VibrationEffect.createWaveform(longArrayOf(0, 60, 110, 60), intArrayOf(0, 200, 0, 200), -1)
            else VibrationEffect.createOneShot(45, if (v.hasAmplitudeControl()) 90 else VibrationEffect.DEFAULT_AMPLITUDE)
        )
    } catch (e: Exception) { LaserLog.add("vibrate: $e") }
}

private val GLIDE = CubicBezierEasing(.3f, .8f, .3f, 1f)

@Composable
fun LaserRadarScreen() {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val real = app.laser.real
    val reduced = remember { reducedMotion(ctx) }

    // ---- the page is open: readings come here, the radar's own countdown and timing ----
    var reading by remember { mutableStateOf<LaserReading?>(null) }
    DisposableEffect(Unit) {
        real.radar = true
        real.clearFailure()
        real.opened()
        app.laser.radarTake = { reading = it }
        LaserLog.add("=== radar page open ===")
        onDispose {
            LaserLog.add("=== radar page closed ===")
            real.radar = false
            app.laser.radarTake = null
            if (real.scanning) real.stopScan()
            real.clearFailure()
            real.kick()
        }
    }

    // ---- what stands in the way (checked again while the page is open: the switches are in the system settings) ----
    val hasBt = real.adapter != null
    var missing by remember { mutableStateOf(LaserPerms.missing(ctx)) }
    var btOn by remember { mutableStateOf(LaserPerms.btOn(ctx)) }
    var locOn by remember { mutableStateOf(LaserPerms.locOk(ctx)) }
    var canConnect by remember { mutableStateOf(LaserPerms.canConnect(ctx)) }
    var denied by remember { mutableStateOf(false) }
    // (equal values change nothing: this redraws the page only when a switch really moved)
    fun refresh() { missing = LaserPerms.missing(ctx); btOn = LaserPerms.btOn(ctx); locOn = LaserPerms.locOk(ctx); canConnect = LaserPerms.canConnect(ctx) }
    LaunchedEffect(Unit) { while (true) { refresh(); delay(1000) } }
    // the clock for "nothing found after 8 s", lasers leaving after 20 s and the scan's wait: once a second, and only while searching
    var now by remember { mutableLongStateOf(SystemClock.uptimeMillis()) }
    var ticking by remember { mutableStateOf(true) }
    LaunchedEffect(ticking) { while (ticking) { now = SystemClock.uptimeMillis(); delay(1000) } }

    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        LaserLog.add("radar permissions: " + res.entries.joinToString { (k, v) -> k.substringAfterLast('.') + "=" + (if (v) "granted" else "denied") })
        refresh()
        denied = missing.isNotEmpty()
        if (!denied) { real.clearFailure(); real.kick() }
    }
    fun askPerms() = try { ask.launch(LaserPerms.needed().toTypedArray()) } catch (e: Exception) { LaserLog.add("permission ask failed: $e") }
    val enableBt = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { refresh() }
    fun turnBtOn() {
        // Android 12+ needs BLUETOOTH_CONNECT before it may ask to turn Bluetooth on
        if (Build.VERSION.SDK_INT >= 31 && !LaserPerms.canConnect(ctx)) { askPerms(); return }
        try { enableBt.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)) }
        catch (e: Exception) { LaserLog.add("BT enable request failed: $e"); LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)) }
    }
    fun openAppSettings() = LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null)))
    // ---- the page's state ----
    // a lost link this page has not answered yet ("Uzish" / "Qidiruvga" answer it)
    var lostAck by remember { mutableIntStateOf(real.lostSeq) }
    val lostActive = real.lostSeq != lostAck
    // when the searching began (null while not searching, so a new search never starts as "nothing found")
    var searchFrom by remember { mutableStateOf<Long?>(null) }
    val fail = real.failure
    val saved = real.savedAddr
    // the remembered laser is being tried in the background (planned or going on): the dashed bubble, no beam
    val savedTrying = saved != null && !real.stopped && !real.paused && (real.retryAt != null || (real.link == Link.CONNECTING && !real.userConnect))
    // the remembered laser is the dashed bubble; every other laser the scan hears shows beside it
    val lasers = real.found.values.filter { it.laser && !RadarMath.stale(it.seen, now) && !(savedTrying && it.address == saved) }.sortedByDescending { it.avg }
    val others = real.found.values.filter { !it.laser }.sortedByDescending { it.rssi }
    // a link that is up or coming up is shown first (a reading is not lost behind a permission card); the scan's
    // permissions and location are needed only for searching
    val mode = when {
        !hasBt -> RMode.NO_BT
        fail == LaserFail.BT_OFF -> RMode.FAILED
        !btOn -> RMode.OFF
        real.connected -> RMode.CONNECTED
        real.link == Link.CONNECTING && (real.userConnect || lostActive) -> RMode.CONNECTING
        fail != null -> RMode.FAILED
        lostActive -> RMode.LOST
        savedTrying -> RMode.SAVED
        missing.isNotEmpty() -> if (denied) RMode.DENIED else RMode.PERM
        !locOn -> RMode.LOC_OFF
        lasers.isNotEmpty() -> RMode.FOUND
        searchFrom.let { it != null && now - it >= 8000 } -> RMode.NONE
        else -> RMode.SEARCH
    }
    val searchish = mode == RMode.SEARCH || mode == RMode.NONE || mode == RMode.FOUND
    // a scan that failed: said on the card while the next start waits (30 s)
    val scanFail = searchish && real.problem == "lz.scanFail"
    SideEffect { ticking = searchish || mode == RMode.SAVED }
    LaunchedEffect(searchish) { searchFrom = if (searchish) SystemClock.uptimeMillis() else null }
    // scan after scan while searching, and beside the remembered laser's tries (15 s each, the list kept); a scan that
    // would not start is tried again (RealLaser keeps it to 4 starts in 30 s, and waits 30 s after a failure)
    val scanMode = (searchish || mode == RMode.SAVED) && missing.isEmpty() && locOn
    LaunchedEffect(scanMode, real.scanning, real.link) {
        if (!scanMode) { if (real.scanning) real.stopScan(); return@LaunchedEffect }
        if (real.scanning || real.link != Link.IDLE) return@LaunchedEffect
        delay(300)
        while (true) { real.startScan(keep = true); delay(3000) }
    }
    // opening the page is asking to search: the permissions are asked once at once (when Bluetooth is on)
    var askedAuto by remember { mutableStateOf(false) }
    LaunchedEffect(mode == RMode.PERM) { if (mode == RMode.PERM && !askedAuto) { askedAuto = true; askPerms() } }
    // "Ruxsat kerak" after a refused connect goes by itself once the permission was given in the settings
    LaunchedEffect(fail, canConnect) { if (fail == LaserFail.PERMISSION && canConnect) { real.clearFailure(); real.kick() } }
    LaunchedEffect(mode) { LaserLog.add("radar: $mode${if (fail != null) " ($fail, try ${real.failStreak})" else ""}") }

    // ---- motion ----
    val glide = remember { Animatable(0f) }      // the laser on its way into the middle (1 = there)
    val gone = remember { Animatable(0f) }       // and fading there
    val snap = remember { Animatable(1f) }       // the snapped beam (1 = over)
    val shake = remember { Animatable(1f) }      // the laser shaking (1 = still)
    val jolt = remember { Animatable(1f) }       // the middle buzzing (1 = still)
    var checkOn by remember { mutableStateOf(mode == RMode.CONNECTED) }
    var seenConnecting by remember { mutableStateOf(false) }
    LaunchedEffect(mode) {
        when (mode) {
            RMode.CONNECTING -> { seenConnecting = true; checkOn = false; glide.snapTo(0f); gone.snapTo(0f); reading = null }
            // the remembered laser coming up by itself gets the same glide, check and buzz as a tapped one
            RMode.SAVED -> { seenConnecting = true; checkOn = false; glide.snapTo(0f); gone.snapTo(0f) }
            RMode.CONNECTED -> {
                if (seenConnecting) {
                    seenConnecting = false
                    if (reduced) glide.snapTo(1f) else glide.animateTo(1f, tween(700, easing = GLIDE))
                    checkOn = true
                    buzz(ctx, twice = false)
                    if (reduced) gone.snapTo(1f) else gone.animateTo(1f, tween(320))
                } else { checkOn = true; glide.snapTo(1f); gone.snapTo(1f) }
            }
            RMode.LOST -> { checkOn = false }
            else -> { checkOn = false; seenConnecting = false; if (mode != RMode.FAILED) { glide.snapTo(0f); gone.snapTo(0f) } }
        }
    }
    suspend fun failFx(line: Boolean) = kotlinx.coroutines.coroutineScope {
        buzz(ctx, twice = true)
        if (reduced) return@coroutineScope
        if (line) launch { snap.snapTo(0f); snap.animateTo(1f, tween(1100, easing = LinearEasing)) }
        launch { shake.snapTo(0f); shake.animateTo(1f, tween(500, easing = LinearEasing)) }
        launch { jolt.snapTo(0f); jolt.animateTo(1f, tween(660, easing = LinearEasing)) }
    }
    val failStart = remember { real.failSeq }
    LaunchedEffect(real.failSeq) {
        val f = real.failure
        if (real.failSeq != failStart && f != null && f != LaserFail.PERMISSION) { glide.snapTo(0f); gone.snapTo(0f); failFx(line = f != LaserFail.BT_OFF) }
    }
    val lostStart = remember { real.lostSeq }
    LaunchedEffect(real.lostSeq) {
        if (real.lostSeq == lostStart) return@LaunchedEffect
        // the laser comes back out of the middle to its spot, then the beam snaps
        gone.snapTo(0f); glide.snapTo(1f)
        if (!reduced) glide.animateTo(0f, tween(600, easing = GLIDE)) else glide.snapTo(0f)
        failFx(line = true)
    }

    // ---- what the radar draws ----
    val many = mode == RMode.FAILED && fail != null && LinkRules.showMany(fail, real.failStreak)
    val grey = mode == RMode.NO_BT || mode == RMode.OFF || mode == RMode.PERM || mode == RMode.DENIED || mode == RMode.LOC_OFF ||
        (mode == RMode.FAILED && (fail == LaserFail.BT_OFF || fail == LaserFail.PERMISSION))
    val active = !grey && (searchish || mode == RMode.SAVED)
    val coreTone = when {
        grey -> Tone.OFF
        mode == RMode.FAILED && fail == LaserFail.NOT_LASER -> Tone.BAD
        mode == RMode.FAILED || mode == RMode.LOST -> Tone.WARN
        mode == RMode.CONNECTED && checkOn -> Tone.OK
        else -> Tone.COBALT
    }
    val coreIcon = when {
        mode == RMode.OFF || mode == RMode.NO_BT || (mode == RMode.FAILED && fail == LaserFail.BT_OFF) -> RI.BTOFF
        mode == RMode.PERM || mode == RMode.DENIED || (mode == RMode.FAILED && fail == LaserFail.PERMISSION) -> RI.SHIELD
        mode == RMode.LOC_OFF -> RI.PIN
        mode == RMode.CONNECTED && checkOn -> RI.CHECK
        many -> RI.HELP
        mode == RMode.FAILED && fail == LaserFail.TIMEOUT -> RI.BANG
        mode == RMode.FAILED && fail == LaserFail.BUSY -> RI.LOCK
        mode == RMode.FAILED && fail == LaserFail.NOT_LASER -> RI.X
        mode == RMode.LOST -> RI.SYNC
        else -> RI.PHONE
    }
    fun bubOf(addr: String?, name: String?, f: (String, String, Int, Float) -> Bub): Bub? {
        if (addr == null) return null
        val d = real.found[addr]
        return f(addr, d?.name ?: name ?: "ZB-08", d?.rssi ?: -60, d?.avg ?: -60f)
    }
    val linkOrSaved = real.linkAddr ?: saved
    val reconnectingWord = tr("lr.reconnecting") + "…"
    // (read as a yes/no: the page is not composed again for every frame of the fade)
    val goneDone by remember { derivedStateOf { gone.value >= 1f } }
    val bubbles: List<Bub> = when (mode) {
        RMode.SEARCH, RMode.NONE, RMode.FOUND -> lasers.map { Bub(it.address, it.name ?: "ZB", it.rssi, it.avg, sig = true) }
        RMode.SAVED -> listOfNotNull(bubOf(saved, real.savedName) { a, n, r, v -> Bub(a, n, r, v, saved = true, sigText = reconnectingWord) }) +
            lasers.map { Bub(it.address, it.name ?: "ZB", it.rssi, it.avg, sig = true) }
        RMode.CONNECTING -> listOfNotNull(bubOf(real.linkAddr, real.linkName) { a, n, r, v -> Bub(a, n, r, v, sig = real.found[a] != null) })
        RMode.CONNECTED -> if (!goneDone) listOfNotNull(bubOf(real.linkAddr, real.linkName) { a, n, r, v -> Bub(a, n, r, v) }) else emptyList()
        RMode.FAILED -> if (fail == LaserFail.PERMISSION) emptyList() else listOfNotNull(bubOf(real.failAddr, real.failName) { a, n, r, v ->
            when (fail) {
                LaserFail.NOT_LASER -> Bub(a, n, r, v, tone = Tone.BAD, badge = RI.X, dim = true)
                LaserFail.BUSY -> Bub(a, n, r, v, tone = Tone.WARN, badge = RI.LOCK)
                LaserFail.BT_OFF -> Bub(a, n, r, v, tone = Tone.OFF, dim = true)
                else -> Bub(a, n, r, v, tone = Tone.WARN)
            }
        })
        RMode.LOST -> listOfNotNull(bubOf(linkOrSaved, real.linkName ?: real.savedName) { a, n, r, v -> Bub(a, n, r, v, tone = Tone.WARN, dim = true) })
        else -> emptyList()
    }
    // the one laser the beam, the glide and the failure are about
    val focusAddr = when (mode) {
        RMode.CONNECTING, RMode.CONNECTED -> real.linkAddr
        RMode.LOST -> linkOrSaved
        RMode.FAILED -> real.failAddr
        else -> null
    }
    val focus = bubbles.firstOrNull { it.addr == focusAddr }
    val beamOn = mode == RMode.CONNECTING
    val snapOn = (mode == RMode.FAILED && fail != LaserFail.BT_OFF && fail != LaserFail.PERMISSION) || mode == RMode.LOST
    fun tapLaser(b: Bub) {
        when (mode) {
            RMode.SEARCH, RMode.NONE, RMode.FOUND -> real.connect(b.addr, b.name)
            RMode.SAVED -> real.connect(b.addr, if (b.addr == saved) real.savedName ?: b.name else b.name)
            else -> {}
        }
    }

    var othersOpen by remember { mutableStateOf(false) }
    BackHandler(othersOpen) { othersOpen = false }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val radarSize = minOf(maxWidth * .84f, maxHeight * .40f, 310.dp)
        Column(Modifier.fillMaxWidth().statusBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(tr("lr.title"), style = ui(19f, 800, spacing = -.01f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(tr("lr.sub"), style = ui(12f, 600, G.ink3), maxLines = 1)
                }
            }
            Spacer(Modifier.height(10.dp))
            RadarView(
                Modifier.size(radarSize), reduced, grey, active, beamOn, snapOn, coreTone, coreIcon, bubbles, focus,
                glide, gone, snap, shake, jolt, ::tapLaser
            )
            StatusText(mode, fail, many, checkOn, lostActive, reduced, real.linkName ?: real.failName ?: real.savedName ?: "ZB-08", lasers.size,
                lasers.firstOrNull()?.name ?: "ZB-08", real.savedName ?: "ZB-08", ((now - (searchFrom ?: now)) / 1000).toInt().coerceAtLeast(0), real.failStreak, real.userConnect)
        }

        // the card at the bottom, one per state (slides up a little when it changes)
        val cardKey = when {
            scanFail -> "scanFail"
            mode == RMode.FAILED -> if (many) "many" else "fail:$fail"
            mode == RMode.FOUND -> "found:" + (lasers.firstOrNull()?.address ?: "")
            mode == RMode.CONNECTED -> if (checkOn) "connected" else "connecting"
            else -> mode.name
        }
        // the card never grows over the words under the radar (Russian, large fonts, the help list): it scrolls instead
        val cardMax = maxHeight * .46f
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().padding(14.dp)) {
            key(cardKey) {
                val rise = remember { Animatable(if (reduced) 1f else 0f) }
                LaunchedEffect(Unit) { rise.animateTo(1f, tween(if (reduced) 1 else 350)) }
                val warnCard = (mode == RMode.FAILED && fail != LaserFail.NOT_LASER) || mode == RMode.LOST || grey || scanFail
                val dens = LocalDensity.current
                Column(Modifier.fillMaxWidth().heightIn(max = cardMax).graphicsLayer { alpha = rise.value; translationY = (1f - rise.value) * with(dens) { 20.dp.toPx() } }
                    .glassCard(RoundedCornerShape(24.dp), fill = if (warnCard) RC.warnBg else G.sheet(.78f), shadowRadius = 30.dp, shadowY = 14.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp)) {
                    val name = real.linkName ?: real.failName ?: real.savedName ?: "ZB-08"
                    val othersLink: @Composable () -> Unit = { CardLink(tr("lr.others", "n" to others.size)) { othersOpen = true } }
                    if (scanFail) {
                        val w = real.scanGate.waitMs(now)
                        CardHead(RI.BANG, Tone.WARN, tr("lr.scanFailTitle"), tr("lz.scanFail") + if (w > 0) "\n" + tr("lr.scanFailWait", "s" to (w + 999) / 1000) else "")
                        othersLink()
                    } else when (mode) {
                        RMode.NO_BT -> CardHead(RI.BTOFF, Tone.WARN, tr("lt.noBt"))
                        RMode.OFF -> {
                            CardHead(RI.BTOFF, Tone.WARN, tr("lr.btOnTitle"), tr("lr.btOnBody"))
                            One(tr("lr.btOn"), ::turnBtOn, icon = "bt")
                        }
                        RMode.PERM -> {
                            CardHead(RI.SHIELD, Tone.WARN, tr("lr.permTitle"), tr(LaserPerms.permKey()))
                            One(tr("lt.permAsk"), { askPerms() })
                        }
                        RMode.DENIED -> {
                            CardHead(RI.SHIELD, Tone.WARN, tr("lr.permTitle"), tr("lr.permBody"))
                            Two(tr("lr.later"), { app.pop() }, tr("lr.settings"), { openAppSettings() })
                        }
                        RMode.LOC_OFF -> {
                            CardHead(RI.PIN, Tone.WARN, tr("lr.locTitle"), tr("lt.locOff"))
                            One(tr("lt.locOpen"), { LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)) })
                        }
                        RMode.SEARCH -> othersLink()
                        RMode.NONE -> {
                            CardHead(RI.INFO, Tone.COBALT, tr("lr.noneTitle"), tr("lr.noneBody"))
                            TipArt()
                            othersLink()
                        }
                        RMode.FOUND -> {
                            val best = lasers.firstOrNull()
                            if (best != null) {
                                CardHead(RI.LASER, Tone.COBALT, best.name ?: "ZB", tr(RadarMath.qualityKey(best.rssi)))
                                One(tr("dv.connect"), { real.connect(best.address, best.name) })
                            }
                            othersLink()
                        }
                        RMode.SAVED -> {
                            val sn = real.savedName ?: "ZB-08"
                            CardHead(RI.LASER, Tone.COBALT, tr("lr.savedTitle", "n" to sn), tr("lr.savedBody"))
                            Two(tr("lz.forget"), { real.forget() }, tr("lr.now"), { saved?.let { real.connect(it, sn) } })
                        }
                        RMode.CONNECTING -> GBtn(tr("common.cancel"), { real.cancelConnect(); lostAck = real.lostSeq }, Btn.SECONDARY, height = 50.dp, corner = 16.dp, fontSize = 15f)
                        RMode.CONNECTED -> if (!checkOn) GBtn(tr("common.cancel"), {}, Btn.SECONDARY, enabled = false, height = 50.dp, corner = 16.dp, fontSize = 15f) else {
                            CardHead(RI.LASER, Tone.COBALT, tr("lr.tryTitle"), tr("lr.tryBody"))
                            ReadingBox(reading, app.settings.unit, app.settings.lang == uz.metrx.app.core.Lang.EN, reduced)
                            One(tr("lr.done"), { app.pop() })
                        }
                        RMode.LOST -> {
                            LostCountdown(real.retryAt, real.retryTotal)
                            Two(tr("dv.disconnect"), { lostAck = real.lostSeq; real.disconnect() }, tr("lr.now"), { linkOrSaved?.let { real.connect(it, name) } })
                        }
                        RMode.FAILED -> {
                            val retry = { real.failAddr?.let { real.connect(it, real.failName) }; Unit }
                            val toSearch = { lostAck = real.lostSeq; real.clearFailure() }
                            when {
                                many -> {
                                    CardHead(RI.HELP, Tone.WARN, tr("lr.fManyTitle"), bullets = listOf(tr("lr.fMany1"), tr("lr.fMany2"), tr("lr.fMany3"), tr("lr.fMany4")))
                                    // the laser test page is there only in test mode (7 taps on Profile's version line)
                                    if (app.settings.devMode) Two(tr("lt.row"), { app.push(Route.LaserTest) }, tr("lr.retry"), retry)
                                    else Two(tr("lr.toSearch"), toSearch, tr("lr.retry"), retry)
                                }
                                fail == LaserFail.TIMEOUT -> {
                                    CardHead(RI.BANG, Tone.WARN, tr("lr.fTimeoutTitle"), bullets = listOf(tr("lr.fTimeout1"), tr("lr.fTimeout2")))
                                    Two(tr("lr.toSearch"), toSearch, tr("lr.retry"), retry)
                                }
                                fail == LaserFail.BUSY -> {
                                    CardHead(RI.LOCK, Tone.WARN, tr("lr.fBusyTitle"), tr("lr.fBusyBody"))
                                    Two(tr("common.cancel"), toSearch, tr("lr.retry"), retry)
                                }
                                fail == LaserFail.NOT_LASER -> {
                                    CardHead(RI.X, Tone.BAD, tr("lr.fNotTitle"), tr("lr.fNotBody"))
                                    One(tr("lr.fNotBtn"), toSearch)
                                }
                                fail == LaserFail.BT_OFF -> {
                                    CardHead(RI.BTOFF, Tone.WARN, tr("lr.fBtTitle"), tr("lr.fBtBody", "n" to name))
                                    One(tr("lr.btOn"), ::turnBtOn, icon = "bt")
                                }
                                else -> {   // PERMISSION
                                    CardHead(RI.SHIELD, Tone.WARN, tr("lr.permTitle"), tr("lr.permBody"))
                                    Two(tr("lr.later"), { real.clearFailure(); app.pop() }, tr("lr.settings"), { openAppSettings() })
                                }
                            }
                        }
                    }
                }
            }
        }

        // the page is itself inside the blur's source: this sheet gets the plain tint (a blur of itself shows the page through)
        if (othersOpen) androidx.compose.runtime.CompositionLocalProvider(uz.metrx.app.ui.glass.LocalHaze provides null) { GlassSheet(tr("lr.othersTitle"), { othersOpen = false }) {
            if (others.isEmpty()) Text(tr("lr.othersNone"), style = ui(13.5f, 500, G.ink2, 1.4f))
            others.take(30).forEach { d ->
                val shape = RoundedCornerShape(16.dp)
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(G.idle(.55f)).border(1.dp, G.idleRim, shape)
                    .pressable({ othersOpen = false; real.connect(d.address, d.name) }, .98f, label = d.name ?: d.address).padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    MIcon("bt", G.ink2, 22.dp, 2f)
                    Column(Modifier.weight(1f)) {
                        Text(d.name ?: "—", style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(d.address + " · ${d.rssi} dBm", style = mono(11.5f, 500, G.ink2), maxLines = 1)
                    }
                    Text(tr("dv.connect"), style = ui(14f, 700, G.cobalt))
                }
            }
        } }
    }
}

// ---------- the radar ----------

private typealias Anim = Animatable<Float, androidx.compose.animation.core.AnimationVector1D>

/**
 * The radar. The moving values (the glide, the fade, the shake, the buzz, the loops) are read only where they are drawn
 * or placed, so a frame of motion redraws, it does not compose the page again; the loops stop when nothing moves.
 */
@Composable
private fun RadarView(
    modifier: Modifier, reduced: Boolean, grey: Boolean, active: Boolean, beamOn: Boolean, snapOn: Boolean, coreTone: Tone, coreIcon: String,
    bubbles: List<Bub>, focus: Bub?, glide: Anim, gone: Anim, snap: Anim, shake: Anim, jolt: Anim, onTap: (Bub) -> Unit
) {
    val radarA = animateFloatAsState(if (active) 1f else 0f, tween(if (reduced) 1 else 400), label = "radar")
    val ringsA = animateFloatAsState(if (active || grey) 1f else 0f, tween(if (reduced) 1 else 400), label = "rings")
    val beamA = animateFloatAsState(if (beamOn) 1f else 0f, tween(if (reduced) 1 else 300), label = "beam")
    // the turning sweep (3 s), the pulses (2.4 s, three staggered), the beam's dashes (.6 s) and dots (1.2 s): only while
    // the radar turns or the beam shows (and while they fade out)
    val moving by remember { derivedStateOf { radarA.value > 0f || beamA.value > 0f } }
    val spin: State<Float>; val pulse: State<Float>; val dash: State<Float>; val dots: State<Float>
    if (!reduced && (moving || active || beamOn)) {
        val inf = rememberInfiniteTransition(label = "radar")
        spin = inf.animateFloat(0f, 360f, infiniteRepeatable(tween(3000, easing = LinearEasing)), label = "spin")
        pulse = inf.animateFloat(0f, 1f, infiniteRepeatable(tween(2400, easing = LinearEasing)), label = "pulse")
        dash = inf.animateFloat(0f, 1f, infiniteRepeatable(tween(600, easing = LinearEasing)), label = "dash")
        dots = inf.animateFloat(0f, 1f, infiniteRepeatable(tween(1200, easing = LinearEasing), RepeatMode.Restart), label = "dots")
    } else {
        val z = remember { mutableStateOf(0f) }
        spin = z; pulse = z; dash = z; dots = z
    }
    val focusRf = animateFloatAsState(focus?.let { RadarMath.radius(it.avg) } ?: RadarMath.R_MIN, if (reduced) androidx.compose.animation.core.snap() else tween(700), label = "focusR")
    val coreColor by animateColorAsState(RC.of(coreTone), tween(if (reduced) 1 else 350), label = "core")
    val density = LocalDensity.current
    val beamTone = RC.of(if (focus?.tone == Tone.BAD) Tone.BAD else Tone.WARN)

    BoxWithConstraints(modifier) {
        val sizePx = with(density) { maxWidth.toPx() }
        val radius = sizePx / 2f
        val coreD = maxWidth * .26f
        val corePx = with(density) { coreD.toPx() } / 2f
        fun spot(b: Bub, rf: Float, g: Float): Offset {
            val a = Math.toRadians(RadarMath.angle(b.addr).toDouble())
            val r = radius * rf * (1f - g)
            return Offset(radius + r * cos(a).toFloat(), radius + r * sin(a).toFloat())
        }
        val cobalt = G.cobalt
        val ringCol = if (grey) RC.hair else RC.cobaltSoft
        Canvas(Modifier.fillMaxSize()) {
            val c = Offset(radius, radius)
            val ra = ringsA.value
            if (ra > 0f) for (k in floatArrayOf(1f, .68f, .36f)) drawCircle(ringCol, radius * k - 1.dp.toPx(), c, alpha = ra, style = Stroke(1.5.dp.toPx()))
            val a = radarA.value
            if (a > 0f && !reduced) {
                rotate(spin.value, c) {
                    drawCircle(Brush.sweepGradient(0f to Color.Transparent, .833f to Color.Transparent, .875f to cobalt.copy(alpha = .05f), 1f to cobalt.copy(alpha = .28f), center = c), radius, c, alpha = a)
                }
                for (i in 0 until 3) {
                    val t = (pulse.value + i / 3f) % 1f
                    val e = 1f - (1f - t) * (1f - t)
                    drawCircle(cobalt, corePx * (1f + 1.6f * e), c, alpha = .55f * (1f - e) * a, style = Stroke(2.dp.toPx()))
                }
            }
            val f = focus
            if (f != null) {
                val p = spot(f, focusRf.value, glide.value)
                val ba = beamA.value
                if (ba > 0f) drawBeam(p, c, cobalt, ba, if (reduced) 0f else dash.value, if (reduced) -1f else dots.value)
                if (snapOn && snap.value < 1f) drawSnap(p, c, beamTone, snap.value, radius)
            }
        }
        // the lasers
        for (b in bubbles) key(b.addr) {
            val isFocus = b.addr == focus?.addr
            val rfAnim = animateFloatAsState(RadarMath.radius(b.avg), if (reduced) androidx.compose.animation.core.snap() else tween(700), label = "r")
            BubbleView(b, density, reduced,
                pos = { spot(b, if (isFocus) focusRf.value else rfAnim.value, if (isFocus) glide.value else 0f) },
                gone = { if (isFocus) gone.value else 0f },
                shakeDp = { if (isFocus && shake.value < 1f) shakeAt(shake.value) else 0f }) { onTap(b) }
        }
        // the phone in the middle
        Box(Modifier.align(Alignment.Center).size(coreD)
            .graphicsLayer { val j = jolt.value; translationX = if (j < 1f) (sin(j * 6f * Math.PI).toFloat() * 3f).dp.toPx() else 0f }
            .dropShadow(CircleShape, Shadow(22.dp, if (coreTone == Tone.OFF) Color.Transparent else coreColor.copy(alpha = .4f), offset = DpOffset(0.dp, 10.dp)))
            .clip(CircleShape).background(coreColor), contentAlignment = Alignment.Center) {
            Crossfade(coreIcon, animationSpec = tween(if (reduced) 1 else 250), label = "coreIcon") { ic ->
                PathIcon(ic, Color.White, coreD * .42f, if (ic == RI.CHECK) 2.8f else 2f)
            }
        }
    }
}

/** The shake's offset in dp at [t] (0…1): −6, 6, −4, 4, 0 as in the mockup. */
private fun shakeAt(t: Float): Float {
    val keys = floatArrayOf(0f, -6f, 6f, -4f, 4f, 0f)
    val x = t * 5f
    val i = x.toInt().coerceIn(0, 4)
    return keys[i] + (keys[i + 1] - keys[i]) * (x - i)
}

/** Variant A: a dashed line from the laser [p] to the phone [c], its dashes moving, three dots flowing both ways. */
private fun DrawScope.drawBeam(p: Offset, c: Offset, color: Color, alpha: Float, dash: Float, dots: Float) {
    val on = 5.dp.toPx(); val offLen = 6.dp.toPx()
    val phase = (1f - dash) * 2f * (on + offLen)
    drawLine(color.copy(alpha = .75f * alpha), p, c, 2.4.dp.toPx(), StrokeCap.Butt, PathEffect.dashPathEffect(floatArrayOf(on, offLen), phase))
    if (dots < 0f) return
    val r = 3.6.dp.toPx()
    // dot 1 and 3 go laser → phone, dot 2 phone → laser (begun .4 s and .8 s later)
    for (i in 0 until 3) {
        val u = ((dots - i / 3f) % 1f + 1f) % 1f
        val q = if (i == 1) lerpO(c, p, u) else lerpO(p, c, u)
        drawCircle(color, r, q, alpha = alpha)
    }
}

/** The link breaking: the line splits in the middle, the gap drifts apart with a small zigzag, then it fades (1.1 s). */
private fun DrawScope.drawSnap(p: Offset, c: Offset, color: Color, t: Float, radius: Float) {
    val ms = t * 1100f
    val len = hypot(p.x - c.x, p.y - c.y).coerceAtLeast(1f)
    val u = Offset((p.x - c.x) / len, (p.y - c.y) / len)      // towards the laser
    val m = Offset((p.x + c.x) / 2f, (p.y + c.y) / 2f)
    val k = radius / 125f                                       // the mockup's stage was 250 px
    val g = (8.5f + (28.3f - 8.5f) * (ms / 350f).coerceIn(0f, 1f)) * k
    val la = if (ms < 600f) 1f else (1f - (ms - 600f) / 500f).coerceIn(0f, 1f)
    val w = 2.4.dp.toPx()
    if (la > 0f) {
        drawLine(color, p, Offset(m.x + u.x * g, m.y + u.y * g), w, StrokeCap.Round, alpha = la)
        drawLine(color, Offset(m.x - u.x * g, m.y - u.y * g), c, w, StrokeCap.Round, alpha = la)
    }
    val za = if (ms < 450f) ms / 450f else (1f - (ms - 450f) / 450f).coerceIn(0f, 1f)
    if (za > 0f) {
        val z = Path().apply {
            moveTo(m.x - 7f * k, m.y - 3f * k); relativeLineTo(5f * k, -4f * k); relativeLineTo(2f * k, 6f * k); relativeLineTo(5f * k, -4f * k)
        }
        drawPath(z, color, alpha = za, style = Stroke(2.2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

private fun lerpO(a: Offset, b: Offset, t: Float) = Offset(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)

/** A laser bubble: glass circle with the laser drawing, its name, its signal; dashed when remembered, grey when dimmed. */
@Composable
private fun BubbleView(b: Bub, density: androidx.compose.ui.unit.Density, reduced: Boolean, pos: () -> Offset, gone: () -> Float, shakeDp: () -> Float, onTap: () -> Unit) {
    val pop = remember { Animatable(if (reduced) 1f else .3f) }
    LaunchedEffect(Unit) { if (!reduced) pop.animateTo(1f, spring(dampingRatio = .45f, stiffness = 420f)) }
    val col = if (b.dim) RC.off else RC.of(b.tone)
    val halfW = with(density) { 48.dp.toPx() }; val halfB = with(density) { 26.dp.toPx() }
    val label = tr("lr.bubble", "n" to b.name)
    Column(
        Modifier.offset { val p = pos(); IntOffset((p.x - halfW + shakeDp() * density.density).roundToInt(), (p.y - halfB).roundToInt()) }.width(96.dp)
            .graphicsLayer {
                val g = gone()
                val s = pop.value * (1f - .6f * g)
                scaleX = s; scaleY = s; transformOrigin = androidx.compose.ui.graphics.TransformOrigin(.5f, 26f / 80f)
                alpha = (pop.value.coerceIn(0f, 1f)) * (1f - g) * (if (b.dim) .6f else 1f)
            }
            .semantics { contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box {
            Box(Modifier.size(52.dp)
                .dropShadow(CircleShape, Shadow(18.dp, col.copy(alpha = if (b.dim) 0f else .25f), offset = DpOffset(0.dp, 8.dp)))
                .clip(CircleShape).background(G.sheet(.8f))
                .drawBehind {
                    val w = 2.dp.toPx()
                    drawCircle(col, size.minDimension / 2f - w / 2f, style = Stroke(w, pathEffect = if (b.saved || b.dim) PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.5.dp.toPx())) else null))
                }
                .pressable(onTap, .94f), contentAlignment = Alignment.Center) {
                PathIcon(RI.LASER, col, 28.dp, 2f)
            }
            if (b.badge != null) Box(Modifier.align(Alignment.TopEnd).offset(6.dp, (-6).dp).size(24.dp)
                .dropShadow(CircleShape, Shadow(6.dp, Color.Black.copy(alpha = .2f), offset = DpOffset(0.dp, 2.dp)))
                .clip(CircleShape).background(RC.of(b.tone)), contentAlignment = Alignment.Center) { PathIcon(b.badge, Color.White, 14.dp, 2.6f) }
        }
        Text(b.name, style = ui(12f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.clip(RoundedCornerShape(9.dp)).background(G.sheet(.8f)).border(1.dp, G.rim, RoundedCornerShape(9.dp)).padding(horizontal = 8.dp, vertical = 2.dp))
        if (b.sigText != null) Text(b.sigText, style = ui(10f, 700, G.ink3), maxLines = 1)
        else if (b.sig) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            SignalBars(RadarMath.bars(b.rssi))
            Text("${b.rssi} dBm", style = ui(10f, 700, G.ink3), maxLines = 1)
        }
    }
}

@Composable
private fun SignalBars(n: Int) {
    val c = G.ink3
    Canvas(Modifier.size(15.dp, 10.dp)) {
        val bw = 2.6.dp.toPx(); val gap = 1.5.dp.toPx()
        for (i in 0 until 4) {
            val h = size.height * (.4f + .2f * i)
            drawRoundRect(c.copy(alpha = if (i < n) 1f else .28f), Offset(i * (bw + gap), size.height - h), Size(bw, h), CornerRadius(1.dp.toPx()))
        }
    }
}

// ---------- the words under the radar ----------

@Composable
private fun StatusText(mode: RMode, fail: LaserFail?, many: Boolean, checkOn: Boolean, lost: Boolean, reduced: Boolean, name: String, nLasers: Int,
                       best: String, savedName: String, secs: Int, streak: Int, user: Boolean) {
    var n by remember { mutableIntStateOf(0) }
    // the moving dots only while a title has them
    val dotted = mode == RMode.SEARCH || mode == RMode.NONE || mode == RMode.SAVED || mode == RMode.CONNECTING || (mode == RMode.CONNECTED && !checkOn)
    LaunchedEffect(reduced, dotted) { if (!reduced && dotted) while (true) { delay(300); n = (n + 1) % 4 } }
    // the missing dots are drawn see-through (HIDDEN_DOT), so the centred title keeps its width and does not jiggle
    fun dots(s: String) = if (reduced) "$s…" else s + ".".repeat(n) + HIDDEN_DOT.toString().repeat(3 - n)
    val connectingTitle = dots(tr(if (lost || !user) "lr.reconnecting" else "lr.connecting")) + if (streak >= 1 && user) " " + tr("lr.try", "k" to streak + 1) else ""
    val (title, sub) = when (mode) {
        RMode.NO_BT -> tr("lt.noBt") to ""
        RMode.OFF -> tr("dev.off") to tr("lr.btOffSub")
        RMode.PERM, RMode.DENIED -> tr("lr.permNeed") to tr("lr.permSub")
        RMode.LOC_OFF -> tr("lr.locOff") to tr("lr.locSub")
        RMode.SEARCH -> dots(tr("lr.searching")) to tr("lr.searchSub")
        RMode.NONE -> dots(tr("lr.searching")) to tr("lr.noneSub", "s" to secs)
        RMode.FOUND -> tr("lr.found", "n" to nLasers) to tr("lr.foundSub", "n" to best)
        RMode.SAVED -> dots(tr("lr.reconnecting")) to tr("lr.savedSub", "n" to savedName)
        RMode.CONNECTING -> connectingTitle to tr("lr.connectingSub", "n" to name)
        RMode.CONNECTED -> if (!checkOn) connectingTitle to tr("lr.connectingSub", "n" to name)
            else if (lost) tr("lr.reconnected", "n" to name) to tr("lr.goOn") else tr("lr.connected", "n" to name) to tr("lr.connectedSub")
        RMode.LOST -> tr("lr.lost") to tr("lr.reconnecting") + "…"
        RMode.FAILED -> when {
            many -> tr("lr.fMany") to tr("lr.fManySub", "k" to streak)
            fail == LaserFail.TIMEOUT -> tr("lr.fTimeout") to tr("lr.fTimeoutSub", "n" to name)
            fail == LaserFail.BUSY -> tr("lr.fBusy") to tr("lr.fBusySub", "n" to name)
            fail == LaserFail.NOT_LASER -> tr("lr.fNot") to tr("lr.fNotSub")
            fail == LaserFail.BT_OFF -> tr("lr.fBt") to tr("lr.fBtSub")
            else -> tr("lr.permNeed") to tr("lr.permSub")
        }
    }
    Column(Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(androidx.compose.ui.text.buildAnnotatedString {
            title.forEach { ch -> if (ch == HIDDEN_DOT) withStyle(androidx.compose.ui.text.SpanStyle(color = Color.Transparent)) { append('.') } else append(ch) }
        }, style = ui(18f, 800, lineHeight = 1.25f).copy(textAlign = TextAlign.Center))
        if (sub.isNotEmpty()) Text(sub, style = ui(13f, 400, G.ink2, 1.45f).copy(textAlign = TextAlign.Center), modifier = Modifier.padding(top = 4.dp))
    }
}

/** A dot of the searching title's "..." not shown yet (drawn see-through). */
private const val HIDDEN_DOT = ''

// ---------- the card's pieces ----------

@Composable
private fun CardHead(icon: String, tone: Tone, title: String, body: String? = null, bullets: List<String> = emptyList()) {
    Row(verticalAlignment = if (body == null && bullets.isEmpty()) Alignment.CenterVertically else Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(RC.soft(tone)), contentAlignment = Alignment.Center) {
            PathIcon(icon, RC.of(tone), 24.dp, 2f)
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 800, lineHeight = 1.3f))
            if (body != null) Text(body, style = ui(13f, 400, G.ink2, 1.45f), modifier = Modifier.padding(top = 4.dp))
            if (bullets.isNotEmpty()) Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                bullets.forEach { s ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("•", style = ui(13f, 700, G.ink2, 1.5f))
                        Text(s, style = ui(13f, 400, G.ink2, 1.5f), modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun One(label: String, onClick: () -> Unit, icon: String? = null) =
    GBtn(label, onClick, icon = icon, modifier = Modifier.padding(top = 12.dp), height = 50.dp, corner = 16.dp, fontSize = 15f)

@Composable
private fun Two(secLabel: String, sec: () -> Unit, label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        GBtn(secLabel, sec, Btn.SECONDARY, modifier = Modifier.weight(1f), height = 48.dp, corner = 15.dp, fontSize = 14f, maxLines = 2)
        GBtn(label, onClick, modifier = Modifier.weight(1f), height = 48.dp, corner = 15.dp, fontSize = 14f, maxLines = 2)
    }
}

@Composable
private fun CardLink(text: String, onClick: () -> Unit) {
    Text(text, style = ui(13f, 700, G.cobalt).copy(textAlign = TextAlign.Center),
        modifier = Modifier.fillMaxWidth().padding(top = 10.dp).clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick).padding(vertical = 8.dp))
}

/** The lost link's card head with its countdown and bar: its own clock (10 a second), so only this part is redrawn. */
@Composable
private fun LostCountdown(at: Long?, total: Long) {
    var t by remember { mutableLongStateOf(SystemClock.uptimeMillis()) }
    LaunchedEffect(at) { while (at != null) { t = SystemClock.uptimeMillis(); if (t >= at) break; delay(100) } }
    val (s, p) = if (at != null) LinkRules.countdown(t, at, total) else 0 to 0f
    CardHead(RI.SYNC, Tone.WARN, tr("lr.lostTitle"), if (at != null) tr("lr.lostBody", "s" to s) else tr("lr.lostBodyIdle"))
    if (at != null) Box(Modifier.padding(top = 10.dp).fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(RC.hair)) {
        Box(Modifier.fillMaxWidth(p).fillMaxHeight().background(RC.warn))
    }
}

/** The "Sinab ko‘ring" box: the next real measurement, with a green "aniq" tag when it came. */
@Composable
private fun ReadingBox(r: LaserReading?, unit: LenUnit, english: Boolean, reduced: Boolean) {
    val hit = remember { Animatable(0f) }
    LaunchedEffect(r) { if (r != null && !reduced) { hit.snapTo(1f); hit.animateTo(0f, tween(600)) } }
    val unitWord = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val shape = RoundedCornerShape(18.dp)
    Column(Modifier.fillMaxWidth().padding(top = 12.dp).clip(shape).background(RC.screen).border(1.dp, RC.hair, shape).padding(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally) {
        if (r == null) Text(tr("lr.last"), style = ui(12f, 700, G.ink3))
        else Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("lr.fromLaser"), style = ui(12f, 700, G.ink3))
            Text(tr("lr.exact"), style = ui(11f, 800, G.green), modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(RC.okSoft).padding(horizontal = 8.dp, vertical = 2.dp))
        }
        val v = if (r == null) "— $unitWord" else fmtLen(r.mm, unit, english, full = true) + " " + unitWord
        Text(v, style = mono(38f, 700, if (r == null) G.ink3 else lerp(G.ink, G.green, hit.value), spacing = -.02f), maxLines = 1,
            modifier = Modifier.padding(top = 2.dp).graphicsLayer { val s = 1f + .12f * hit.value; scaleX = s; scaleY = s })
    }
}

/** The "nothing found" tip: a simple drawing of the laser with its Bluetooth button lit. */
@Composable
private fun TipArt() {
    val shape = RoundedCornerShape(14.dp)
    val cobalt = G.cobalt; val soft = RC.cobaltSoft; val screen = RC.screen
    Row(Modifier.fillMaxWidth().padding(top = 10.dp).clip(shape).background(RC.screen).border(1.dp, RC.hair, shape).padding(10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Canvas(Modifier.size(86.dp, 48.dp)) {
            val k = size.width / 86f
            fun o(x: Float, y: Float) = Offset(x * k, y * k)
            drawRoundRect(soft, o(4f, 6f), Size(60f * k, 36f * k), CornerRadius(7f * k))
            drawRoundRect(cobalt, o(4f, 6f), Size(60f * k, 36f * k), CornerRadius(7f * k), style = Stroke(2f * k))
            drawRoundRect(screen, o(12f, 13f), Size(26f * k, 12f * k), CornerRadius(2f * k))
            drawRoundRect(cobalt, o(12f, 13f), Size(26f * k, 12f * k), CornerRadius(2f * k), style = Stroke(1.5f * k))
            drawCircle(cobalt, 9f * k, o(52f, 19f), alpha = .5f, style = Stroke(1.5f * k))
            drawCircle(cobalt, 5f * k, o(52f, 19f))
            val rune = Path().apply { moveTo(50f * k, 16.5f * k); lineTo(54f * k, 20.5f * k); lineTo(52f * k, 22.5f * k); lineTo(52f * k, 13.5f * k); lineTo(54f * k, 15.5f * k); lineTo(50f * k, 19.5f * k) }
            drawPath(rune, Color.White, style = Stroke(1.2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawLine(cobalt, o(64f, 24f), o(82f, 24f), 2f * k, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f * k, 3f * k)))
        }
        val tip = tr("lr.noneTip")
        val parts = tip.split("{bt}")
        val text = buildAnnotatedString { append(parts[0]); if (parts.size > 1) { appendInlineContent("bt", "ᛒ"); append(parts[1]) } }
        Text(text, style = ui(12f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f),
            inlineContent = mapOf("bt" to InlineTextContent(Placeholder(13.sp, 13.sp, PlaceholderVerticalAlign.TextCenter)) { PathIcon(RI.BT, G.cobalt, 13.dp, 2.6f) }))
    }
}
