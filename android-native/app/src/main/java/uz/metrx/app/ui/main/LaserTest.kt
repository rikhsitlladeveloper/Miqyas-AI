@file:SuppressLint("MissingPermission")

package uz.metrx.app.ui.main

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.IntentCompat
import kotlinx.coroutines.delay
import uz.metrx.app.laser.JrtEvent
import uz.metrx.app.laser.JrtParser
import uz.metrx.app.laser.LaserLog
import uz.metrx.app.laser.LaserPerms
import uz.metrx.app.laser.RealLaser
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.GlassButton
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.mono
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/*
 * Device sheet → "Lazer sinovi": a tool to learn how a Bluetooth laser rangefinder talks (the ZB-08 was decoded with it;
 * the app's own support is laser/RealLaser.kt, which steps aside while this page is open).
 *
 * It finds devices both ways (BLE scan and classic discovery, plus paired ones), connects over BLE GATT or classic SPP
 * and ONLY READS: it reads readable characteristics, and the one thing it ever writes is the standard CCCD (0x2902)
 * that turns notifications/indications on. Over SPP it only reads the input stream. Every log line also goes to
 * logcat: `adb logcat -s METRX-LASER`.
 */

private const val TAG = "METRX-LASER"
private const val SCAN_S = 20
private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
private val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
private val USER_DESC_UUID: UUID = UUID.fromString("00002901-0000-1000-8000-00805f9b34fb")

/** Reading the bytes a laser sends: hex, ASCII, and candidate distances (pure, unit-tested). */
object LaserDecode {
    fun hex(b: ByteArray): String = b.joinToString(" ") { "%02X".format(it.toInt() and 0xFF) }
    fun ascii(b: ByteArray): String = String(CharArray(b.size) { i -> val c = b[i].toInt() and 0xFF; if (c in 0x20..0x7E) c.toChar() else '.' })

    /** The FNIRSI IR40 rule: big-endian uint16 at offset 14, in mm. Not proven for the ZB-08. */
    fun fnirsi(b: ByteArray): Double? = if (b.size >= 16) (((b[14].toInt() and 0xFF) shl 8) or (b[15].toInt() and 0xFF)) / 1000.0 else null

    private val NUM = Regex("""(-?\d+(?:[.,]\d+)?)\s*(mm|cm|m|ft|in|")?""", RegexOption.IGNORE_CASE)

    /** Numbers in text like "1.234m", "1234mm", "D=1.234": "1.234m = 1.234 m". Empty for data that is mostly not text. */
    fun textNumbers(b: ByteArray): List<String> {
        if (b.isEmpty()) return emptyList()
        val printable = b.count { (it.toInt() and 0xFF) in 0x20..0x7E || it.toInt() == 0x0D || it.toInt() == 0x0A }
        if (printable * 10 < b.size * 6) return emptyList()
        val s = String(CharArray(b.size) { i -> val c = b[i].toInt() and 0xFF; if (c in 0x20..0x7E) c.toChar() else ' ' })
        return NUM.findAll(s).mapNotNull { m ->
            val v = m.groupValues[1].replace(',', '.').toDoubleOrNull() ?: return@mapNotNull null
            val unit = m.groupValues[2].lowercase()
            // a bare whole number with no unit is too vague to call a distance
            if (unit.isEmpty() && !m.groupValues[1].contains('.') && !m.groupValues[1].contains(',')) return@mapNotNull null
            val metres = when (unit) { "mm" -> v / 1000; "cm" -> v / 100; "ft" -> v * .3048; "in", "\"" -> v * .0254; else -> v }
            m.value.trim() + " = " + "%.3f m".format(Locale.US, metres)
        }.toList()
    }

    /** 0x2A00 for a Bluetooth base UUID, the full UUID otherwise, with a known name. */
    fun uuid(u: UUID): String {
        val s = u.toString().lowercase()
        val short = if (s.startsWith("0000") && s.endsWith("-0000-1000-8000-00805f9b34fb")) "0x" + s.substring(4, 8).uppercase() else s
        return KNOWN[short]?.let { "$short ($it)" } ?: short
    }

    private val KNOWN = mapOf(
        "0x1800" to "Generic Access", "0x1801" to "Generic Attribute", "0x180A" to "Device Information", "0x180F" to "Battery",
        "0x1101" to "Serial Port (SPP)", "0x2A00" to "Device Name", "0x2A01" to "Appearance", "0x2A04" to "Conn. Parameters",
        "0x2A05" to "Service Changed", "0x2A19" to "Battery Level", "0x2A23" to "System ID", "0x2A24" to "Model Number",
        "0x2A25" to "Serial Number", "0x2A26" to "Firmware Rev", "0x2A27" to "Hardware Rev", "0x2A28" to "Software Rev",
        "0x2A29" to "Manufacturer", "0x2A50" to "PnP ID", "0x2902" to "CCCD", "0x2901" to "User Description",
        "0xFFE0" to "HM-10 style UART service", "0xFFE1" to "HM-10 style UART data", "0xFFF0" to "vendor UART service",
        "0xEE01" to "FNIRSI-like service", "0xEE02" to "FNIRSI-like notify", "0xEE03" to "FNIRSI-like write",
        "6e400001-b5a3-f393-e0a9-e50e24dcca9e" to "Nordic UART service", "6e400002-b5a3-f393-e0a9-e50e24dcca9e" to "Nordic UART RX",
        "6e400003-b5a3-f393-e0a9-e50e24dcca9e" to "Nordic UART TX"
    )

    fun props(p: Int): String = listOf(
        BluetoothGattCharacteristic.PROPERTY_BROADCAST to "BROADCAST", BluetoothGattCharacteristic.PROPERTY_READ to "READ",
        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE to "WRITE_NO_RESP", BluetoothGattCharacteristic.PROPERTY_WRITE to "WRITE",
        BluetoothGattCharacteristic.PROPERTY_NOTIFY to "NOTIFY", BluetoothGattCharacteristic.PROPERTY_INDICATE to "INDICATE",
        BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE to "SIGNED_WRITE", BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS to "EXT_PROPS"
    ).filter { p and it.first != 0 }.joinToString(",") { it.second }.ifEmpty { "none" } + " (0x%02X)".format(p)
}

/** A device seen by the scan, the classic discovery or the paired list. */
data class LtDev(
    val address: String, val name: String?, val type: Int, val rssi: Int?, val bonded: Boolean, val viaLe: Boolean, val viaClassic: Boolean,
    val uuids: List<String> = emptyList(), val mfr: String? = null, val svcData: String? = null, val raw: String? = null, val cls: String? = null
) {
    val zb get() = name?.contains("ZB", ignoreCase = true) == true
    val typeLabel get() = when (type) {
        BluetoothDevice.DEVICE_TYPE_LE -> "LE"; BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"; BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"; else -> "unknown"
    }
}

enum class LtConn { IDLE, CONNECTING, CONNECTED }

/** Scanning, connecting and logging; all its Compose state is changed on the main thread. */
class LaserProbe(private val ctx: Context) {
    private val main = Handler(Looper.getMainLooper())
    val adapter: BluetoothAdapter? = ctx.getSystemService(BluetoothManager::class.java)?.adapter

    val devices = mutableStateMapOf<String, LtDev>()
    var scanning by mutableStateOf(false); private set
    var scanLeft by mutableStateOf(0); private set
    var conn by mutableStateOf(LtConn.IDLE); private set
    var connKind by mutableStateOf<String?>(null); private set
    var connAddr by mutableStateOf<String?>(null); private set
    val services = mutableStateListOf<String>()
    var last by mutableStateOf<String?>(null); private set

    private fun log(s: String) = LaserLog.add(s)
    private fun onMain(f: () -> Unit) { if (Looper.myLooper() == Looper.getMainLooper()) f() else main.post(f) }

    // ---------- start / stop ----------

    private var receiverOn = false
    fun start() {
        log("===== METRX laser test: ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) =====")
        log("BLE feature: ${ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)}, adapter: ${if (adapter == null) "none" else if (safe { adapter.isEnabled } == true) "on" else "off"}")
        val f = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND); addAction(BluetoothDevice.ACTION_NAME_CHANGED); addAction(BluetoothDevice.ACTION_UUID)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED); addAction(BluetoothDevice.ACTION_ACL_CONNECTED); addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED); addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED); addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
        }
        try { ContextCompat.registerReceiver(ctx, receiver, f, ContextCompat.RECEIVER_EXPORTED); receiverOn = true } catch (e: Exception) { log("receiver not registered: $e") }
    }

    fun dispose() {
        stopScan(quiet = true)
        disconnect()
        if (receiverOn) { try { ctx.unregisterReceiver(receiver) } catch (_: Exception) {}; receiverOn = false }
        main.removeCallbacksAndMessages(null)
        log("===== laser test page closed =====")
    }

    // ---------- scanning ----------

    private val tick = object : Runnable {
        override fun run() { scanLeft -= 1; if (scanLeft <= 0) stopScan() else main.postDelayed(this, 1000) }
    }
    private var leOn = false

    fun startScan() {
        val a = adapter ?: return
        if (scanning) return
        if (safe { a.isEnabled } != true) { log("scan: Bluetooth is off"); return }
        scanning = true; scanLeft = SCAN_S
        log("=== scan start: BLE (low latency, no filters) + classic discovery + paired, $SCAN_S s ===")
        try {
            a.bondedDevices.orEmpty().forEach { d ->
                val name = safe { d.name }
                val uu = safe { d.uuids }?.map { LaserDecode.uuid(it.uuid) }.orEmpty()
                val old = devices[d.address]
                devices[d.address] = (old ?: LtDev(d.address, name, safe { d.type } ?: 0, null, true, false, false))
                    .copy(name = name ?: old?.name, bonded = true, uuids = (old?.uuids.orEmpty() + uu).distinct())
                log("paired: ${name ?: "—"} ${d.address} type=${devices[d.address]?.typeLabel} uuids=${uu.ifEmpty { listOf("—") }.joinToString()}")
            }
        } catch (e: Exception) { log("paired list failed: $e") }
        val sc = safe { a.bluetoothLeScanner }
        if (sc == null) log("BLE scanner not available")
        else try {
            sc.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), leCb); leOn = true
            log("BLE scan started")
        } catch (e: Exception) { log("BLE scan failed to start: $e") }
        startDiscovery(a)
        main.postDelayed(tick, 1000)
    }

    private fun startDiscovery(a: BluetoothAdapter) {
        try { if (a.isDiscovering) a.cancelDiscovery(); log("classic discovery start: ${a.startDiscovery()}") } catch (e: Exception) { log("classic discovery failed: $e") }
    }

    fun stopScan(quiet: Boolean = false) {
        main.removeCallbacks(tick)
        if (leOn) { try { adapter?.bluetoothLeScanner?.stopScan(leCb) } catch (_: Exception) {}; leOn = false }
        try { if (adapter?.isDiscovering == true) adapter.cancelDiscovery() } catch (_: Exception) {}
        if (!scanning) return
        scanning = false; scanLeft = 0
        if (!quiet) {
            val zb = devices.values.filter { it.zb }
            log("=== scan stop: ${devices.size} device(s); with \"ZB\" in the name: ${if (zb.isEmpty()) "none" else zb.joinToString { "${it.name} ${it.address} (${it.typeLabel})" }} ===")
        }
    }

    private val leCb = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { onMain { onLe(result) } }
        override fun onBatchScanResults(results: MutableList<ScanResult>) { onMain { results.forEach { onLe(it) } } }
        override fun onScanFailed(errorCode: Int) {
            val why = when (errorCode) { 1 -> "already started"; 2 -> "app registration failed"; 3 -> "internal error"; 4 -> "feature unsupported"; 5 -> "out of hardware resources"; 6 -> "scanning too frequently"; else -> "?" }
            log("BLE scan failed: code $errorCode ($why)")
        }
    }

    private fun onLe(r: ScanResult) {
        val d = r.device
        val rec = r.scanRecord
        val name = rec?.deviceName ?: safe { d.name }
        val uu = rec?.serviceUuids?.map { LaserDecode.uuid(it.uuid) }.orEmpty()
        val mfr = rec?.manufacturerSpecificData?.let { sa -> (0 until sa.size()).joinToString("; ") { i -> "0x%04X: %s".format(sa.keyAt(i), LaserDecode.hex(sa.valueAt(i))) } }?.ifEmpty { null }
        val sd = rec?.serviceData?.entries?.joinToString("; ") { (k, v) -> LaserDecode.uuid(k.uuid) + ": " + LaserDecode.hex(v) }?.ifEmpty { null }
        val raw = rec?.bytes?.let { b -> var n = b.size; while (n > 0 && b[n - 1].toInt() == 0) n--; LaserDecode.hex(b.copyOf(n)) }
        val old = devices[d.address]
        val dev = (old ?: LtDev(d.address, name, safe { d.type } ?: 0, r.rssi, false, true, false)).copy(
            name = name ?: old?.name, rssi = r.rssi, viaLe = true, type = safe { d.type } ?: old?.type ?: 0,
            uuids = (old?.uuids.orEmpty() + uu).distinct(), mfr = mfr ?: old?.mfr, svcData = sd ?: old?.svcData, raw = raw ?: old?.raw
        )
        devices[d.address] = dev
        val desc = "${dev.name ?: "—"} ${d.address} type=${dev.typeLabel} rssi=${r.rssi} connectable=${if (Build.VERSION.SDK_INT >= 26) r.isConnectable else "?"}" +
            " uuids=${uu.ifEmpty { listOf("—") }.joinToString()} mfr=${mfr ?: "—"} svcData=${sd ?: "—"}"
        when {
            old == null || !old.viaLe -> log("BLE found: $desc\n    adv: ${raw ?: "—"}")
            name != null && old.name == null -> log("BLE name: $desc")
            // a ZB device's advertising may itself carry the reading: each change is logged
            (dev.zb || d.address == connAddr) && raw != null && raw != old.raw -> log("BLE adv changed: ${dev.name ?: "—"} ${d.address} rssi=${r.rssi}\n    adv: $raw")
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            val d = IntentCompat.getParcelableExtra(i, BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            when (i.action) {
                BluetoothDevice.ACTION_FOUND -> if (d != null) {
                    val rssi = i.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt().takeIf { it != Short.MIN_VALUE.toInt() }
                    val name = i.getStringExtra(BluetoothDevice.EXTRA_NAME) ?: safe { d.name }
                    val bc = IntentCompat.getParcelableExtra(i, BluetoothDevice.EXTRA_CLASS, BluetoothClass::class.java)
                    val cls = bc?.let { "major 0x%04X, class 0x%06X".format(it.majorDeviceClass, it.deviceClass) }
                    val old = devices[d.address]
                    val dev = (old ?: LtDev(d.address, name, safe { d.type } ?: 0, rssi, false, false, true)).copy(
                        name = name ?: old?.name, rssi = rssi ?: old?.rssi, viaClassic = true, type = safe { d.type } ?: old?.type ?: 0, cls = cls ?: old?.cls
                    )
                    devices[d.address] = dev
                    if (old == null || !old.viaClassic) log("classic found: ${dev.name ?: "—"} ${d.address} type=${dev.typeLabel} rssi=${rssi ?: "?"} class=${cls ?: "—"}")
                }
                BluetoothDevice.ACTION_NAME_CHANGED -> if (d != null) {
                    val name = i.getStringExtra(BluetoothDevice.EXTRA_NAME)
                    devices[d.address]?.let { if (name != null && it.name != name) { devices[d.address] = it.copy(name = name); log("name: $name ${d.address}") } }
                }
                BluetoothDevice.ACTION_UUID -> if (d != null) {
                    val uu = IntentCompat.getParcelableArrayExtra(i, BluetoothDevice.EXTRA_UUID, ParcelUuid::class.java)?.map { LaserDecode.uuid((it as ParcelUuid).uuid) }.orEmpty()
                    log("SDP uuids of ${d.address}: ${uu.ifEmpty { listOf("—") }.joinToString()}")
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> if (d != null) {
                    val st = when (i.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)) { BluetoothDevice.BOND_BONDED -> "paired"; BluetoothDevice.BOND_BONDING -> "pairing…"; BluetoothDevice.BOND_NONE -> "not paired"; else -> "?" }
                    log("bond: ${d.address} → $st")
                    devices[d.address]?.let { devices[d.address] = it.copy(bonded = st == "paired") }
                }
                BluetoothDevice.ACTION_ACL_CONNECTED -> log("ACL link up: ${d?.address}")
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> log("ACL link down: ${d?.address}")
                BluetoothAdapter.ACTION_DISCOVERY_STARTED -> log("classic discovery: started")
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    log("classic discovery: finished")
                    // discovery lasts about 12 s: it runs again for the rest of the 20 s
                    val a = adapter
                    if (scanning && scanLeft > 3 && a != null) startDiscovery(a)
                }
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val st = when (i.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)) { BluetoothAdapter.STATE_ON -> "on"; BluetoothAdapter.STATE_OFF -> "off"; BluetoothAdapter.STATE_TURNING_ON -> "turning on"; BluetoothAdapter.STATE_TURNING_OFF -> "turning off"; else -> "?" }
                    log("Bluetooth: $st")
                    if (st == "turning off" || st == "off") { stopScan(); disconnect() }
                }
            }
        }
    }

    // ---------- BLE GATT ----------

    private var gatt: BluetoothGatt? = null
    private var discovered = false
    private sealed interface Op {
        data class Read(val c: BluetoothGattCharacteristic) : Op
        data class ReadDesc(val d: BluetoothGattDescriptor) : Op
        data class Cccd(val c: BluetoothGattCharacteristic) : Op
    }
    private val ops = ArrayDeque<Op>()
    private var cur: Op? = null
    private var nNotify = 0
    private val opTimeout = Runnable { log("  (no answer in 4 s, next)"); nextOp() }
    private val mtuTimeout = Runnable { gatt?.let { log("MTU: no answer in 4 s"); discover(it) } }

    fun connectLe(addr: String) {
        val a = adapter ?: return
        disconnect(); stopScan()
        val d = try { a.getRemoteDevice(addr) } catch (e: Exception) { log("BLE: bad address $addr: $e"); return }
        conn = LtConn.CONNECTING; connKind = "BLE"; connAddr = addr; services.clear(); discovered = false; nNotify = 0
        log("=== BLE connect ${devices[addr]?.name ?: "—"} $addr (TRANSPORT_LE, autoConnect=false) ===")
        gatt = try { d.connectGatt(ctx, false, gattCb, BluetoothDevice.TRANSPORT_LE) } catch (e: Exception) { log("BLE connectGatt failed: $e"); null }
        if (gatt == null) { conn = LtConn.IDLE; connKind = null }
    }

    private fun discover(g: BluetoothGatt) {
        main.removeCallbacks(mtuTimeout)
        if (discovered || g != gatt) return
        discovered = true
        log("discovering services: ${safe { g.discoverServices() }}")
    }

    private val gattCb = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            onMain {
                val st = when (newState) { BluetoothProfile.STATE_CONNECTED -> "connected"; BluetoothProfile.STATE_DISCONNECTED -> "disconnected"; BluetoothProfile.STATE_CONNECTING -> "connecting"; else -> "disconnecting" }
                log("GATT: $st (status $status${if (status == 133) " = GATT_ERROR, often a timeout or the device busy/asleep" else if (status == 8) " = link timeout" else if (status == 19) " = closed by device" else ""})")
                if (g != gatt) return@onMain
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    conn = LtConn.CONNECTED
                    val asked = safe { g.requestMtu(247) } == true
                    log("MTU 247 asked: $asked")
                    if (asked) main.postDelayed(mtuTimeout, 4000) else discover(g)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    main.removeCallbacks(opTimeout); main.removeCallbacks(mtuTimeout); ops.clear(); cur = null
                    safe { g.close() }; gatt = null
                    conn = LtConn.IDLE; connKind = null
                }
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) { onMain { log("MTU: $mtu (status $status)"); discover(g) } }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) { onMain { if (g == gatt) servicesFound(g, status) } }

        @Deprecated("Android 12 and older")
        override fun onCharacteristicRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") val v = c.value?.copyOf() ?: ByteArray(0)
            onMain { readDone(c, v, status) }
        }
        override fun onCharacteristicRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            val v = value.copyOf(); onMain { readDone(c, v, status) }
        }

        @Deprecated("Android 12 and older")
        override fun onDescriptorRead(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") val v = d.value?.copyOf() ?: ByteArray(0)
            onMain { descReadDone(d, v, status) }
        }
        override fun onDescriptorRead(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int, value: ByteArray) {
            val v = value.copyOf(); onMain { descReadDone(d, v, status) }
        }

        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
            onMain {
                log("  CCCD of ${LaserDecode.uuid(d.characteristic.uuid)}: ${if (status == BluetoothGatt.GATT_SUCCESS) "on" else "status $status"}")
                if (status == BluetoothGatt.GATT_SUCCESS) nNotify++
                val op = cur
                if (op is Op.Cccd && op.c == d.characteristic) nextOp()
            }
        }

        @Deprecated("Android 12 and older")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") val v = c.value?.copyOf() ?: ByteArray(0)
            data("BLE " + LaserDecode.uuid(c.uuid), v)
        }
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            data("BLE " + LaserDecode.uuid(c.uuid), value.copyOf())
        }
    }

    private fun servicesFound(g: BluetoothGatt, status: Int) {
        log("services discovered (status $status): ${g.services.size}")
        services.clear(); ops.clear()
        for (s in g.services) {
            val sl = "SERVICE ${LaserDecode.uuid(s.uuid)} ${if (s.type == BluetoothGattService.SERVICE_TYPE_PRIMARY) "primary" else "secondary"}"
            services.add(sl); log(sl)
            for (c in s.characteristics) {
                val cl = "  CHAR ${LaserDecode.uuid(c.uuid)} [${LaserDecode.props(c.properties)}] id=${c.instanceId}"
                services.add(cl); log(cl)
                for (d in c.descriptors) { val dl = "    DESC ${LaserDecode.uuid(d.uuid)}"; services.add(dl); log(dl) }
                if (c.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) ops.add(Op.Read(c))
                c.getDescriptor(USER_DESC_UUID)?.let { ops.add(Op.ReadDesc(it)) }
            }
        }
        // reads first, then notifications on: the CCCD is the only thing ever written
        for (s in g.services) for (c in s.characteristics) {
            if (c.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) ops.add(Op.Cccd(c))
        }
        log("reading ${ops.count { it !is Op.Cccd }} value(s), then turning on ${ops.count { it is Op.Cccd }} notification(s)…")
        nextOp()
    }

    private fun nextOp() {
        main.removeCallbacks(opTimeout)
        val g = gatt ?: run { cur = null; return }
        val op = ops.removeFirstOrNull()
        cur = op
        if (op == null) {
            log("=== ready: notifications on for $nNotify characteristic(s). Take a reading on the laser now. ===")
            return
        }
        val started = when (op) {
            is Op.Read -> safe { g.readCharacteristic(op.c) } == true
            is Op.ReadDesc -> safe { g.readDescriptor(op.d) } == true
            is Op.Cccd -> enableCccd(g, op.c)
        }
        if (started) main.postDelayed(opTimeout, 4000)
        else { log("  could not start: ${opText(op)}"); main.post { if (cur === op) nextOp() } }
    }

    private fun opText(op: Op) = when (op) {
        is Op.Read -> "read " + LaserDecode.uuid(op.c.uuid)
        is Op.ReadDesc -> "read descriptor of " + LaserDecode.uuid(op.d.characteristic.uuid)
        is Op.Cccd -> "notifications on " + LaserDecode.uuid(op.c.uuid)
    }

    /** The only write this tool ever makes: the standard CCCD (0x2902) value that turns notifications or indications on. */
    private fun enableCccd(g: BluetoothGatt, c: BluetoothGattCharacteristic): Boolean {
        val local = safe { g.setCharacteristicNotification(c, true) } == true
        val d = c.getDescriptor(CCCD_UUID)
        if (d == null) { log("  ${LaserDecode.uuid(c.uuid)}: no CCCD; notifications set locally only ($local)"); return false }
        check(d.uuid == CCCD_UUID)
        val v = if (c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE else BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        log("  CCCD write ${LaserDecode.hex(v)} → ${LaserDecode.uuid(c.uuid)} (${if (v.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) "notify" else "indicate"})")
        return safe {
            if (Build.VERSION.SDK_INT >= 33) g.writeDescriptor(d, v) == BluetoothStatusCodes.SUCCESS
            else { @Suppress("DEPRECATION") d.value = v; @Suppress("DEPRECATION") g.writeDescriptor(d) }
        } == true
    }

    private fun readDone(c: BluetoothGattCharacteristic, v: ByteArray, status: Int) {
        log("  READ ${LaserDecode.uuid(c.uuid)} status=$status len=${v.size} hex=[${LaserDecode.hex(v)}] ascii=\"${LaserDecode.ascii(v)}\"")
        val op = cur
        if (op is Op.Read && op.c == c) nextOp()
    }

    private fun descReadDone(d: BluetoothGattDescriptor, v: ByteArray, status: Int) {
        log("  READ desc ${LaserDecode.uuid(d.uuid)} of ${LaserDecode.uuid(d.characteristic.uuid)} status=$status ascii=\"${LaserDecode.ascii(v)}\" hex=[${LaserDecode.hex(v)}]")
        val op = cur
        if (op is Op.ReadDesc && op.d == d) nextOp()
    }

    /** A notification or an SPP chunk: logged with every decoding that might be a distance. */
    private fun data(src: String, b: ByteArray) {
        val sb = StringBuilder("DATA $src len=${b.size}\n    hex:   ${LaserDecode.hex(b)}\n    ascii: \"${LaserDecode.ascii(b)}\"")
        val guesses = mutableListOf<String>()
        // the ZB-08's JRT frames (laser/Jrt.kt), as the app itself reads them
        if (src.startsWith("BLE")) for (e in jrt.feed(b, android.os.SystemClock.uptimeMillis())) if (e is JrtEvent.Reading) guesses += "JRT result = ${e.mm} mm (q ${e.quality})"
        LaserDecode.fnirsi(b)?.let { guesses += "FNIRSI rule (BE u16 @14 /1000) = %.3f m".format(Locale.US, it) }
        LaserDecode.textNumbers(b).forEach { guesses += "text: $it" }
        guesses.forEach { sb.append("\n    → ").append(it) }
        log(sb.toString())
        if (guesses.isNotEmpty()) {
            val t = synchronized(timeFmt) { timeFmt.format(Date()) }
            onMain { last = "$t  " + guesses.joinToString("  |  ") }
        }
    }
    private val timeFmt = SimpleDateFormat("HH:mm:ss", Locale.US)
    private val jrt = JrtParser()

    // ---------- classic SPP ----------

    @Volatile private var socket: BluetoothSocket? = null
    @Volatile private var sppThread: Thread? = null

    fun connectSpp(addr: String) {
        val a = adapter ?: return
        disconnect(); stopScan()
        val d = try { a.getRemoteDevice(addr) } catch (e: Exception) { log("SPP: bad address $addr: $e"); return }
        conn = LtConn.CONNECTING; connKind = "SPP"; connAddr = addr; services.clear()
        log("=== classic SPP connect ${devices[addr]?.name ?: "—"} $addr; cached uuids: ${safe { d.uuids }?.joinToString { LaserDecode.uuid(it.uuid) } ?: "—"} ===")
        val t = Thread({ runSpp(a, d) }, "metrx-laser-spp")
        sppThread = t; t.start()
    }

    private fun runSpp(a: BluetoothAdapter, d: BluetoothDevice) {
        val me = Thread.currentThread()
        safe { a.cancelDiscovery() }
        val tries = listOf<Pair<String, () -> BluetoothSocket>>(
            "secure RFCOMM to the SPP UUID" to { d.createRfcommSocketToServiceRecord(SPP_UUID) },
            "insecure RFCOMM to the SPP UUID" to { d.createInsecureRfcommSocketToServiceRecord(SPP_UUID) },
            "RFCOMM channel 1 (fallback)" to { d.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType).invoke(d, 1) as BluetoothSocket }
        )
        var s: BluetoothSocket? = null
        for ((label, make) in tries) {
            if (sppThread !== me) return
            try {
                log("SPP: trying $label…")
                val x = make(); socket = x
                x.connect(); s = x
                log("SPP: connected ($label)")
                break
            } catch (e: Exception) {
                log("SPP: $label failed: ${e.javaClass.simpleName}: ${e.message}")
                try { socket?.close() } catch (_: Exception) {}
                socket = null
            }
        }
        if (s == null) {
            log("SPP: could not connect")
            onMain { if (sppThread === me) { sppThread = null; conn = LtConn.IDLE; connKind = null } }
            return
        }
        onMain { if (sppThread === me) conn = LtConn.CONNECTED }
        val line = StringBuilder()
        try {
            val inp = s.inputStream
            val buf = ByteArray(1024)
            while (sppThread === me) {
                val n = inp.read(buf)
                if (n < 0) break
                val chunk = buf.copyOf(n)
                data("SPP", chunk)
                // text lines may come in several chunks: a whole line is decoded again when it ends
                for (byte in chunk) {
                    val c = byte.toInt() and 0xFF
                    if (c == 0x0A || c == 0x0D) {
                        if (line.isNotEmpty()) { val l = line.toString(); line.clear(); val nums = LaserDecode.textNumbers(l.toByteArray()); log("SPP line: \"$l\"" + nums.joinToString("") { "\n    → text: $it" }) }
                    } else if (line.length < 512) line.append(if (c in 0x20..0x7E) c.toChar() else '.')
                }
            }
        } catch (e: IOException) {
            log("SPP: stream closed: ${e.message}")
        }
        try { s.close() } catch (_: Exception) {}
        log("SPP: disconnected")
        onMain { if (sppThread === me) { sppThread = null; socket = null; conn = LtConn.IDLE; connKind = null } }
    }

    // ---------- disconnect ----------

    fun disconnect() {
        main.removeCallbacks(opTimeout); main.removeCallbacks(mtuTimeout); ops.clear(); cur = null
        gatt?.let { g -> log("BLE: disconnect"); safe { g.disconnect() }; safe { g.close() } }
        gatt = null
        if (sppThread != null || socket != null) log("SPP: disconnect")
        sppThread = null
        socket?.let { try { it.close() } catch (_: Exception) {} }
        socket = null
        conn = LtConn.IDLE; connKind = null
    }

    private inline fun <T> safe(f: () -> T): T? = try { f() } catch (e: SecurityException) { log("permission missing: ${e.message}"); null } catch (_: Exception) { null }
}

/** The runtime permissions the test needs (shared with the Device sheet: laser/LaserLog.kt LaserPerms). */
private fun ltNeeded(): List<String> = LaserPerms.needed()

private fun ltMissing(ctx: Context) = LaserPerms.missing(ctx)

private fun open(ctx: Context, intent: Intent) = LaserPerms.open(ctx, intent)

@Composable
fun LaserTestScreen() {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val probe = remember { LaserProbe(ctx.applicationContext) }
    // the app's own laser connection steps aside while this page has Bluetooth, and comes back after
    DisposableEffect(probe) { RealLaser.get(ctx).pause(); probe.start(); onDispose { probe.dispose(); RealLaser.get(ctx).resume() } }

    var missing by remember { mutableStateOf(ltMissing(ctx)) }
    var asked by remember { mutableStateOf(false) }
    var btOn by remember { mutableStateOf(false) }
    var locOn by remember { mutableStateOf(true) }
    fun refresh() {
        missing = ltMissing(ctx)
        btOn = try { probe.adapter?.isEnabled == true } catch (_: Exception) { false }
        locOn = LaserPerms.locOk(ctx)   // location services matter for scanning up to Android 11 only
    }
    // the switches are turned in the system settings: their state is checked again every second
    LaunchedEffect(Unit) { while (true) { refresh(); delay(1000) } }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        asked = true
        LaserLog.add("permissions: " + res.entries.joinToString { (k, v) -> k.substringAfterLast('.') + "=" + (if (v) "granted" else "denied") })
        refresh()
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }); Text(tr("lt.row"), style = ui(17f, 700), modifier = Modifier.weight(1f))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(tr("lt.intro"), style = ui(14f, 400, G.ink2, 1.45f))

            // what stands in the way: no Bluetooth, Bluetooth off, location off, permissions
            when {
                probe.adapter == null -> Notice(tr("lt.noBt"))
                !btOn -> Notice(tr("lt.btOff")) { GlassButton(tr("lt.btOpen"), { open(ctx, Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)) }, primary = false, icon = "bt") }
            }
            if (probe.adapter != null && !locOn) Notice(tr("lt.locOff")) {
                GlassButton(tr("lt.locOpen"), { open(ctx, Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)) }, primary = false)
            }
            if (probe.adapter != null && missing.isNotEmpty()) Notice(tr(LaserPerms.permKey()) +"\n" + missing.joinToString { it.substringAfterLast('.') }) {
                GlassButton(tr("lt.permAsk"), { ask.launch(ltNeeded().toTypedArray()) })
                if (asked) GlassButton(tr("lt.permApp"), {
                    open(ctx, Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null)))
                }, primary = false)
            }

            val canScan = probe.adapter != null && btOn && missing.isEmpty()
            if (probe.scanning) GlassButton(tr("lt.stop") + " · " + tr("lt.scanning", "s" to probe.scanLeft), { probe.stopScan() }, primary = false, icon = "search")
            else GlassButton(tr("lt.scan"), { probe.startScan() }, icon = "search", enabled = canScan, modifier = Modifier.alpha(if (canScan) 1f else .45f))

            // the devices, strongest first; a name with "ZB" stands out
            val list = probe.devices.values.sortedWith(compareByDescending<LtDev> { it.rssi ?: Int.MIN_VALUE }.thenBy { it.address })
            Text(tr("lt.devices", "n" to list.size), style = ui(13f, 600, G.ink2), modifier = Modifier.padding(top = 4.dp))
            if (list.isEmpty()) Text(tr("lt.none"), style = ui(13f, 400, G.ink3))
            var sel by remember { mutableStateOf<String?>(null) }
            list.take(80).forEach { d ->
                DeviceCard(d, sel == d.address, probe.conn == LtConn.IDLE, { sel = if (sel == d.address) null else d.address }, { probe.connectLe(d.address) }, { probe.connectSpp(d.address) })
            }

            if (probe.conn != LtConn.IDLE || probe.connAddr != null) {
                Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(18.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val st = when (probe.conn) { LtConn.IDLE -> "lt.st.idle"; LtConn.CONNECTING -> "lt.st.connecting"; LtConn.CONNECTED -> "lt.st.connected" }
                    Text(tr(st) + (probe.connKind?.let { " · $it" } ?: ""), style = ui(15f, 700, if (probe.conn == LtConn.CONNECTED) G.green else G.ink))
                    probe.connAddr?.let { a -> Text((probe.devices[a]?.name ?: "—") + "  " + a, style = mono(12f, 500, G.ink2)) }
                    probe.last?.let { l ->
                        Text(tr("lt.last"), style = ui(12f, 600, G.ink3))
                        Text(l, style = mono(13f, 600, G.cobalt))
                    }
                    if (probe.conn != LtConn.IDLE) GlassButton(tr("lt.disconnect"), { probe.disconnect() }, primary = false)
                }
            }

            if (probe.services.isNotEmpty()) {
                Text(tr("lt.services"), style = ui(13f, 600, G.ink2), modifier = Modifier.padding(top = 4.dp))
                SelectionContainer {
                    Text(probe.services.joinToString("\n"), style = mono(10.5f, 500, G.ink),
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(14.dp)).padding(10.dp))
                }
            }

            // the log: newest at the bottom, selectable; copy, clear, save to a file
            Text(tr("lt.log") + " (${LaserLog.lines.size})", style = ui(13f, 600, G.ink2), modifier = Modifier.padding(top = 4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SmallBtn(tr("lt.copy"), "copy", Modifier.weight(1f)) {
                    ctx.getSystemService(ClipboardManager::class.java)?.setPrimaryClip(ClipData.newPlainText("METRX laser log", LaserLog.text()))
                    app.say("lt.copied", kind = ToastKind.OK)
                }
                SmallBtn(tr("lt.clear"), "trash", Modifier.weight(1f)) { LaserLog.clear() }
                SmallBtn(tr("lt.save"), "save", Modifier.weight(1.3f)) {
                    val path = saveLog(ctx)
                    if (path != null) app.say("lt.saved", "f" to path, kind = ToastKind.OK) else app.say("lt.saveFail", kind = ToastKind.ERROR)
                }
            }
            val logScroll = rememberScrollState()
            val shown = LaserLog.lines.takeLast(400)
            LaunchedEffect(LaserLog.lines.size) { delay(40); logScroll.scrollTo(logScroll.maxValue) }
            SelectionContainer {
                Text(shown.joinToString("\n").ifEmpty { "—" }, style = mono(10.5f, 500, G.ink),
                    modifier = Modifier.fillMaxWidth().height(380.dp).clip(RoundedCornerShape(14.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(14.dp))
                        .verticalScroll(logScroll).padding(10.dp))
            }
        }
    }
}

/** Writes the whole log to files/laser/ (and the app's folder on the phone's storage, Android/data/uz.metrx.app/files/laser/). */
private fun saveLog(ctx: Context): String? {
    val text = LaserLog.text()
    val name = "laser-" + SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date()) + ".txt"
    var shown: String? = null
    for (dir in listOfNotNull(ctx.filesDir, ctx.getExternalFilesDir(null))) {
        try {
            val f = File(dir, "laser").apply { mkdirs() }.let { File(it, name) }
            f.writeText(text + "\n")
            LaserLog.add("log saved: ${f.absolutePath}")
            if (shown == null || dir != ctx.filesDir) shown = f.absolutePath
        } catch (e: Exception) { LaserLog.add("log not saved in $dir: $e") }
    }
    // the whole log once more in logcat, line by line, for adb logcat -s METRX-LASER
    Log.i(TAG, "----- saved log $name begin -----")
    text.lineSequence().forEach { Log.i(TAG, "[file] $it") }
    Log.i(TAG, "----- saved log $name end -----")
    return shown
}

@Composable
private fun Notice(text: String, buttons: (@Composable () -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.amberWash).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MIcon("alert", G.amberInk, 20.dp, 2f); Text(text, style = ui(14f, 600, G.amberInk, 1.4f))
        }
        buttons?.invoke()
    }
}

@Composable
private fun SmallBtn(label: String, icon: String, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(modifier.height(40.dp).clip(shape).background(G.glass(.6f)).border(1.dp, G.rim, shape).pressable(onClick, .97f, label = label).padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        MIcon(icon, G.ink, 16.dp, 2f); Text(label, style = ui(12.5f, 600), maxLines = 1)
    }
}

@Composable
private fun DeviceCard(d: LtDev, open: Boolean, canConnect: Boolean, onTap: () -> Unit, onLe: () -> Unit, onSpp: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(if (d.zb) G.blueWash else G.glass(.55f)).border(if (d.zb) 2.dp else 1.dp, if (d.zb) G.cobalt else G.rim, shape)
            .pressable(onTap, .99f, label = d.name ?: d.address).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon(if (d.zb) "laser" else "bt", if (d.zb) G.cobalt else G.ink2, 20.dp, 2f)
            Text(d.name ?: "—", style = ui(15f, 700, if (d.zb) G.cobalt else G.ink), modifier = Modifier.weight(1f), maxLines = 1)
            Text(d.rssi?.let { "$it dBm" } ?: "", style = mono(12f, 600, G.ink2))
        }
        val via = listOfNotNull("BLE".takeIf { d.viaLe }, "classic".takeIf { d.viaClassic }, tr("lt.bonded").takeIf { d.bonded }).joinToString(", ")
        Text("${d.address} · ${d.typeLabel}" + (if (via.isNotEmpty()) " · $via" else ""), style = mono(11.5f, 500, G.ink2))
        if (d.uuids.isNotEmpty()) Text("uuids: " + d.uuids.joinToString(), style = mono(10.5f, 500, G.ink3))
        d.mfr?.let { Text("mfr: $it", style = mono(10.5f, 500, G.ink3)) }
        d.svcData?.let { Text("svc: $it", style = mono(10.5f, 500, G.ink3)) }
        d.cls?.let { Text("class: $it", style = mono(10.5f, 500, G.ink3)) }
        if (open) {
            if (d.raw != null) Text("adv: " + d.raw, style = mono(10f, 500, G.ink3))
            // the transport the device showed first is the main button; the other one is there too, to try both
            val leFirst = d.type == BluetoothDevice.DEVICE_TYPE_LE || (d.viaLe && !d.viaClassic && d.type != BluetoothDevice.DEVICE_TYPE_CLASSIC)
            Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassButton(tr("lt.connLe"), onLe, primary = leFirst, enabled = canConnect, modifier = Modifier.weight(1f).alpha(if (canConnect) 1f else .45f))
                GlassButton(tr("lt.connSpp"), onSpp, primary = !leFirst, enabled = canConnect, modifier = Modifier.weight(1f).alpha(if (canConnect) 1f else .45f))
            }
        }
    }
}
