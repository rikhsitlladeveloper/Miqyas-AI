package uz.metrx.app.ui.main

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import uz.metrx.app.laser.FoundDev
import uz.metrx.app.laser.LaserLog
import uz.metrx.app.laser.LaserPerms
import uz.metrx.app.laser.Link
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GlassButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.mono
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/**
 * The measuring device (prototype SHEETS.device): the real ZB-08 over Bluetooth, and the simulator for when there is
 * none. "Qidirish" opens the laser radar (main/LaserRadar.kt), which finds and connects the laser; a scan's results still
 * show here (lasers first, other named devices under them; a tap connects). The laser connected
 * last is remembered and connected again by itself (opening this sheet tries it at once); "Uzish" disconnects and
 * stops that until the next start, "Unutish" forgets it. Typing values always works.
 */
@Composable
fun DeviceSheet(onClose: () -> Unit, onTest: () -> Unit = {}, onRadar: () -> Unit = {}) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val rl = app.laser
    val real = rl.real
    LaunchedEffect(Unit) { real.opened() }

    var missing by remember { mutableStateOf(LaserPerms.missing(ctx)) }
    var asked by remember { mutableStateOf(false) }
    var btOn by remember { mutableStateOf(LaserPerms.btOn(ctx)) }
    var locOn by remember { mutableStateOf(LaserPerms.locOk(ctx)) }
    var scanAfterAsk by remember { mutableStateOf(false) }
    fun refresh() { missing = LaserPerms.missing(ctx); btOn = LaserPerms.btOn(ctx); locOn = LaserPerms.locOk(ctx) }
    // the switches are turned in the phone's settings: checked again every second while the sheet is open
    LaunchedEffect(Unit) { while (true) { refresh(); delay(1000) } }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        asked = true
        LaserLog.add("permissions: " + res.entries.joinToString { (k, v) -> k.substringAfterLast('.') + "=" + (if (v) "granted" else "denied") })
        refresh()
        if (scanAfterAsk && missing.isEmpty() && btOn) real.startScan()
        scanAfterAsk = false
        if (missing.isEmpty()) real.kick()
    }
    val hasBt = real.adapter != null
    val canScan = hasBt && btOn && missing.isEmpty()
    fun search() {
        when {
            !hasBt -> app.say("lt.noBt", kind = ToastKind.INFO)
            missing.isNotEmpty() -> { scanAfterAsk = true; ask.launch(LaserPerms.needed().toTypedArray()) }
            !btOn -> LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS))
            else -> real.startScan()
        }
    }

    GlassSheet(tr("dv.title"), onClose, footer = {
        when {
            real.connected -> GlassButton(tr("dv.disconnect"), { real.disconnect() }, primary = false)
            real.scanning -> GlassButton(tr("lt.stop") + " · " + tr("lt.scanning", "s" to real.scanLeft), { real.stopScan() }, primary = false, icon = "search")
            // "Qidirish" opens the radar page (it asks for Bluetooth and the permissions itself)
            else -> GlassButton(tr("dv.search"), { if (hasBt) onRadar() else search() }, icon = "search")
        }
    }) {
        // the state, in the words every screen uses
        val st = when {
            real.connected || rl.simOn -> "dev.conn"
            real.scanning -> "dev.scan"
            real.link == Link.CONNECTING -> "lz.connecting"
            else -> "dev.disc"
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(tr("dv.status"), style = ui(14f, 500, G.ink2), modifier = Modifier.weight(1f))
            Text(tr(st), style = ui(14f, 700, if (st == "dev.conn") G.green else G.ink))
        }

        // what stands in the way of the real laser (the test page's checks and words)
        if (!real.connected && !real.paused) {
            when {
                !hasBt -> LaserNotice(tr("lt.noBt"))
                !btOn -> LaserNotice(tr("lt.btOff")) { GlassButton(tr("lt.btOpen"), { LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)) }, primary = false, icon = "bt") }
                missing.isNotEmpty() -> LaserNotice(tr(LaserPerms.permKey())) {
                    GlassButton(tr("lt.permAsk"), { ask.launch(LaserPerms.needed().toTypedArray()) })
                    if (asked) GlassButton(tr("lt.permApp"), { LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null))) }, primary = false)
                }
                // finding devices needs location services up to Android 11 (from Android 12 the Bluetooth permissions only)
                !locOn -> LaserNotice(tr("lt.locOff")) { GlassButton(tr("lt.locOpen"), { LaserPerms.open(ctx, Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)) }, primary = false) }
            }
        }
        real.problem?.let { p -> if (!real.connected) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("alert", G.err, 18.dp, 2f); Text(tr(p), style = ui(13.5f, 500, G.err, 1.4f), modifier = Modifier.weight(1f)) } }

        // the real laser: connected, or the remembered one
        val savedAddr = real.savedAddr
        if (real.connected) RealCard(real.linkName ?: "ZB-08", real.linkAddr ?: "", tr("lz.press"), G.green) {
            Text(tr("lz.forget"), style = ui(14f, 600, G.err), modifier = Modifier.clip(RoundedCornerShape(10.dp)).pressable({ real.forget(); app.say("lz.forgot", kind = ToastKind.OK) }, .97f, label = tr("lz.forget")).padding(horizontal = 6.dp, vertical = 10.dp))
        } else if (savedAddr != null && !real.paused) {
            val connecting = real.link == Link.CONNECTING && real.linkAddr == savedAddr
            val line = when { connecting -> tr("lz.connecting"); real.stopped -> tr("lz.off"); else -> tr("lz.retry") }
            RealCard(real.savedName ?: "ZB-08", savedAddr, tr("lz.saved") + " · " + line, G.ink2) {
                if (!connecting && canConnectNow(ctx)) GBtn(tr("dv.connect"), { real.connect(savedAddr, real.savedName) }, height = 40.dp, corner = 12.dp, fontSize = 14f, fill = false)
                Text(tr("lz.forget"), style = ui(14f, 600, G.err), modifier = Modifier.clip(RoundedCornerShape(10.dp)).pressable({ real.forget(); app.say("lz.forgot", kind = ToastKind.OK) }, .97f, label = tr("lz.forget")).padding(horizontal = 6.dp, vertical = 10.dp))
            }
        }

        // what the scan found: lasers first, then other named devices
        if (!real.connected) {
            val all = real.found.values.toList()
            val lasers = all.filter { it.laser }.sortedByDescending { it.rssi }
            val others = all.filter { !it.laser }.sortedByDescending { it.rssi }
            if (real.scanning || all.isNotEmpty()) Text(tr("dv.found"), style = ui(13f, 700, G.ink3))
            val busy = real.link == Link.CONNECTING
            lasers.forEach { d -> DevRow(d, busy && real.linkAddr == d.address, !busy && canScan) { real.connect(d.address, d.name) } }
            if (real.scanned && !real.scanning && lasers.isEmpty()) Text(tr("lz.none"), style = ui(13.5f, 500, G.ink2, 1.4f))
            if (others.isNotEmpty()) {
                Text(tr("lz.others"), style = ui(13f, 700, G.ink3), modifier = Modifier.padding(top = 4.dp))
                others.take(12).forEach { d -> DevRow(d, busy && real.linkAddr == d.address, !busy && canScan) { real.connect(d.address, d.name) } }
            }
        }

        // the simulator, for trying the app without a laser (only while no real laser is connected)
        if (!real.connected) {
            Text(tr("lz.simHead"), style = ui(13f, 700, G.ink3), modifier = Modifier.padding(top = 4.dp))
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, if (rl.simOn) G.green else G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon("laser", G.cobalt, 24.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(tr("dv.simDev"), style = ui(15.5f, 700))
                    Text(tr("nt.simLaser"), style = ui(13f, 500, G.amberInk, 1.35f))
                }
                if (rl.simOn) GBtn(tr("dv.disconnect"), { rl.simOn = false }, Btn.SECONDARY, height = 40.dp, corner = 12.dp, fontSize = 14f, fill = false)
                else GBtn(tr("dv.connect"), { rl.simOn = true; app.sheet = null; app.say("dv.connected", kind = ToastKind.OK) }, height = 40.dp, corner = 12.dp, fontSize = 14f, fill = false)
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("kbd", G.ink2, 18.dp, 2f); Text(tr("dv.always"), style = ui(13f, 400, G.ink2, 1.4f))
        }
        // a real laser's own signal, read only (main/LaserTest.kt)
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp))
            .pressable(onTest, .98f, label = tr("lt.row")).padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MIcon("bt", G.cobalt, 22.dp, 2f)
            Column(Modifier.weight(1f)) {
                Text(tr("lt.row"), style = ui(15f, 700))
                Text(tr("lt.rowSub"), style = ui(13f, 400, G.ink2, 1.35f))
            }
            MIcon("chev", G.ink2, 18.dp, 2f)
        }
    }
}

private fun canConnectNow(ctx: android.content.Context) = LaserPerms.hasBt(ctx) && LaserPerms.btOn(ctx) && LaserPerms.canConnect(ctx)

@Composable
private fun RealCard(name: String, addr: String, line: String, lineColor: androidx.compose.ui.graphics.Color, actions: @Composable () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(Modifier.fillMaxWidth().clip(shape).background(G.blueWash).border(2.dp, G.cobalt, shape).padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MIcon("laser", G.cobalt, 24.dp, 2f)
            Column(Modifier.weight(1f)) {
                Text(if (lineColor == G.green) tr("lz.connTo", "n" to name) else name, style = ui(15.5f, 700))
                Text(addr, style = mono(11.5f, 500, G.ink2))
            }
        }
        Text(line, style = ui(13f, 500, lineColor, 1.35f))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) { actions() }
    }
}

@Composable
private fun DevRow(d: FoundDev, connecting: Boolean, enabled: Boolean, onTap: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(if (d.laser) G.blueWash else G.glass(.55f)).border(if (d.laser) 2.dp else 1.dp, if (d.laser) G.cobalt else G.rim, shape)
        .let { if (enabled) it.pressable(onTap, .98f, label = d.name ?: d.address) else it }.padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MIcon(if (d.laser) "laser" else "bt", if (d.laser) G.cobalt else G.ink2, 22.dp, 2f)
        Column(Modifier.weight(1f)) {
            Text(d.name ?: "—", style = ui(15f, 700, if (d.laser) G.cobalt else G.ink), maxLines = 1)
            Text(d.address + " · ${d.rssi} dBm", style = mono(11.5f, 500, G.ink2), maxLines = 1)
        }
        Text(tr(if (connecting) "lz.connecting" else "dv.connect"), style = ui(14f, 700, if (enabled || connecting) G.cobalt else G.ink3))
    }
}

/** An amber notice with optional buttons (Bluetooth off, permissions, location), as on the test page. */
@Composable
internal fun LaserNotice(text: String, buttons: (@Composable () -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.amberWash).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MIcon("alert", G.amberInk, 20.dp, 2f); Text(text, style = ui(14f, 600, G.amberInk, 1.4f))
        }
        buttons?.invoke()
    }
}
