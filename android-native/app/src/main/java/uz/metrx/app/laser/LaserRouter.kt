package uz.metrx.app.laser

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Laser
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/**
 * Where each laser measurement goes, app-wide (App.laser).
 *
 * With the real laser connected ([real]), a measurement goes, in this order, to:
 *  1. the app's "Lazer" button that is waiting for it ([await]; the "Lazerda o‘lchang…" bar with Cancel shows meanwhile),
 *  2. the size the screen (or its sheet) has in focus ([LaserSink], the newest one first; a sink may pass),
 *  3. the readings' inbox (settings.readings, src "laser"), which the editor's tray and the Measure page show.
 * Without the real laser, the screens make up readings as before ("sim"), when the simulator is connected ([simOn]).
 */
class LaserRouter(private val app: App) {
    val real: RealLaser = RealLaser.get(app.ctx)
    /** The simulated laser is "connected" (founder decision: kept for when no real laser is there). */
    var simOn by mutableStateOf(false)

    /** A real laser is connected: every laser button waits for its measurement, nothing is made up. */
    val isReal get() = real.connected

    /** The state every screen shows (settings.laser). */
    fun state(): Laser = when {
        real.connected || simOn -> Laser.CONNECTED
        real.scanning || (real.link == Link.CONNECTING && real.userConnect) -> Laser.SEARCHING
        real.found.values.any { it.laser } -> Laser.FOUND
        else -> Laser.DISCONNECTED
    }

    /** A button waiting for the next measurement, made on page [owner] (leaving the page cancels it). */
    class Waiter(val owner: Route, val onCancel: (() -> Unit)?, val take: (Int) -> Unit)
    var waiter by mutableStateOf<Waiter?>(null); private set

    /** The app's "Lazer" button with the real laser: the next measurement goes to [take]. */
    fun await(onCancel: (() -> Unit)? = null, take: (Int) -> Unit) {
        val old = waiter
        waiter = null
        old?.onCancel?.invoke()
        waiter = Waiter(app.top, onCancel, take)
    }

    fun cancel() { val w = waiter ?: return; waiter = null; w.onCancel?.invoke() }

    class Sink(val take: (Int) -> Boolean)
    private val sinks = ArrayList<Sink>()
    fun addSink(take: (Int) -> Boolean) = Sink(take).also { sinks.add(it) }
    fun removeSink(s: Sink) { sinks.remove(s) }

    /** The radar page's "Sinab ko‘ring" box: while the page is open, a measurement goes there first. */
    var radarTake: ((LaserReading) -> Unit)? = null

    /** A measurement from the real laser (main thread). */
    fun dispatch(r: LaserReading) {
        if (r.mm <= 0) return
        radarTake?.let { t -> LaserLog.add("reading ${r.mm} mm → the radar page"); t(r); return }
        waiter?.let { w -> waiter = null; LaserLog.add("reading ${r.mm} mm → the waiting button"); w.take(r.mm); return }
        for (s in sinks.asReversed().toList()) if (s.take(r.mm)) { LaserLog.add("reading ${r.mm} mm → the size in focus"); return }
        app.settings.addReading(r.mm, "laser")
        LaserLog.add("reading ${r.mm} mm → the readings' inbox")
        app.say("lz.inbox", "v" to fmtLen(r.mm, app.settings.unit, app.settings.lang == uz.metrx.app.core.Lang.EN, full = true) + " " +
            app.t(if (app.settings.unit == uz.metrx.app.geo.LenUnit.CM) "u.cm" else "u.m"), kind = ToastKind.INFO)
    }

    /** The real laser's news, said as a toast; a laser picked in the open Device sheet closes it. */
    fun event(kind: String, name: String?, user: Boolean) {
        when (kind) {
            "connected" -> {
                simOn = false
                if (user && app.sheet == uz.metrx.app.ui.Sheet.Device) app.sheet = null
                // the radar page shows it in big (green centre, "Ulandi")
                if (!real.radar) app.say("lz.connected", "n" to (name ?: "ZB-08"), kind = ToastKind.OK)
            }
            // elsewhere a toast and a reconnect after 1 s; the radar page has its own 4 s countdown card
            "lost" -> { cancel(); if (!real.radar) app.say("lz.lost", kind = ToastKind.INFO) }
        }
    }
}

/**
 * While this is on screen, a real-laser measurement goes to [take] (the size in focus); [take] returns false to pass
 * it on (to a sink below, or the readings' inbox). The newest sink on screen (a sheet over its page) comes first.
 */
@Composable
fun LaserSink(take: (Int) -> Boolean) {
    val app = LocalApp.current
    val cur by rememberUpdatedState(take)
    DisposableEffect(Unit) {
        val s = app.laser.addSink { mm -> cur(mm) }
        onDispose { app.laser.removeSink(s) }
    }
}

/** "Lazerda o‘lchang…" at the top while a button waits for the real laser, with Cancel. */
@Composable
fun LaserWaitBar(app: App) {
    val w = app.laser.waiter
    Box(Modifier.fillMaxSize().statusBarsPadding().padding(start = 10.dp, end = 10.dp, top = 8.dp), contentAlignment = Alignment.TopCenter) {
        AnimatedVisibility(w != null, enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it - 40 } + fadeOut()) {
            val shape = RoundedCornerShape(18.dp)
            Row(Modifier.fillMaxWidth().heightIn(min = 58.dp).clip(shape).background(Color(0xFF0F1626)).padding(start = 12.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(32.dp).clip(CircleShape).background(Color(0xFF9DB1FF).copy(alpha = .2f)), contentAlignment = Alignment.Center) { MIcon("laser", Color(0xFF9DB1FF), 18.dp, 2.2f) }
                Column(Modifier.weight(1f)) {
                    Text(tr("lz.wait"), style = ui(14.5f, 700, Color.White, 1.3f))
                    Text(tr("lz.waitSub"), style = ui(12.5f, 500, Color.White.copy(alpha = .7f), 1.3f))
                }
                Box(Modifier.heightIn(min = 42.dp).clip(RoundedCornerShape(13.dp)).background(Color.White.copy(alpha = .12f))
                    .clickable(role = Role.Button) { app.laser.cancel() }.padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
                    Text(tr("common.cancel"), style = ui(14f, 700, Color.White), maxLines = 1)
                }
            }
        }
    }
}
