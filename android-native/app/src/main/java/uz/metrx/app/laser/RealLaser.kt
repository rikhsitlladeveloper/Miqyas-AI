@file:SuppressLint("MissingPermission")

package uz.metrx.app.laser

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import uz.metrx.app.core.Settings
import java.util.UUID

/*
 * The real ZB-08 laser over Bluetooth LE, app-wide (one for the whole process, so it outlives screens and sheets).
 *
 * GATT: the Dialog SPS service; the laser's measurements come as notifications on its TX characteristic (…cb8) as JRT
 * frames (Jrt.kt). The ONLY thing ever written to the laser is the standard CCCD (0x2902) that turns notifications on
 * (on TX, and on flow control …cb9, as the working test did). No commands: the builder measures with the laser's own
 * button. The last laser's address is kept in Settings; it is connected again by itself when the app starts, after the
 * link drops and when Bluetooth comes back on, with a growing pause between tries.
 *
 * All Compose state here is changed on the main thread.
 */

object Sps {
    val SERVICE: UUID = UUID.fromString("0783b03e-8535-b5a0-7140-a304d2495cb7")
    val TX: UUID = UUID.fromString("0783b03e-8535-b5a0-7140-a304d2495cb8")
    val FLOW: UUID = UUID.fromString("0783b03e-8535-b5a0-7140-a304d2495cb9")
    val RX: UUID = UUID.fromString("0783b03e-8535-b5a0-7140-a304d2495cba")
    val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
}

enum class Link { IDLE, CONNECTING, CONNECTED }

/** A device the scan saw: [laser] when its name starts with "ZB" or it shows the SPS service. */
data class FoundDev(val address: String, val name: String?, val rssi: Int, val laser: Boolean)

/** One measurement from the real laser. */
data class LaserReading(val mm: Int, val quality: Int, val ts: Long)

class RealLaser private constructor(private val ctx: Context) {
    private val main = Handler(Looper.getMainLooper())
    val adapter: BluetoothAdapter? = ctx.getSystemService(BluetoothManager::class.java)?.adapter
    private var settings: Settings? = null

    var link by mutableStateOf(Link.IDLE); private set
    var linkAddr by mutableStateOf<String?>(null); private set
    var linkName by mutableStateOf<String?>(null); private set
    /** The connecting now going on was asked for in the Device sheet (not a reconnect in the background). */
    var userConnect by mutableStateOf(false); private set
    var scanning by mutableStateOf(false); private set
    var scanLeft by mutableStateOf(0); private set
    /** True once a scan ran to its end (the sheet then says when no laser was found). */
    var scanned by mutableStateOf(false); private set
    val found = mutableStateMapOf<String, FoundDev>()
    /** When the next reconnect try is planned (uptime ms), null when none is. */
    var retryAt by mutableStateOf<Long?>(null); private set
    /** "Uzish" was pressed: no reconnect by itself until the app starts again or "Ulash" is pressed. */
    var stopped by mutableStateOf(false); private set
    /** The last thing that went wrong, as a string key (lz.failed, lz.notLaser, lz.scanFail), cleared by the next try. */
    var problem by mutableStateOf<String?>(null); private set
    /** The "Lazer sinovi" page has Bluetooth to itself. */
    var paused by mutableStateOf(false); private set

    /** Each measurement; set by the app (LaserRouter). */
    var onReading: ((LaserReading) -> Unit)? = null
    /** "connected" (with the name) or "lost": said to the builder by the app. */
    var onEvent: ((String, String?, Boolean) -> Unit)? = null

    val connected get() = link == Link.CONNECTED
    val savedAddr get() = settings?.laserAddr
    val savedName get() = settings?.laserName

    private fun log(s: String) = LaserLog.add(s)
    private fun onMain(f: () -> Unit) { if (Looper.myLooper() == Looper.getMainLooper()) f() else main.post(f) }
    private inline fun <T> safe(f: () -> T): T? = try { f() } catch (e: SecurityException) { log("permission missing: ${e.message}"); null } catch (_: Exception) { null }

    // ---------- start ----------

    private var started = false

    /** Called by every new app screen with its settings; the first call also tries the remembered laser. */
    fun attach(s: Settings) {
        settings = s
        if (started) return
        started = true
        try {
            ContextCompat.registerReceiver(ctx, btReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED), ContextCompat.RECEIVER_EXPORTED)
        } catch (e: Exception) { log("BT state receiver not registered: $e") }
        if (s.laserAddr != null) { log("start: remembered laser ${s.laserName ?: "—"} ${s.laserAddr}"); attempt = 0; plan(300) }
    }

    private val btReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)) {
                BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_OFF -> {
                    log("Bluetooth off: link and scan stop")
                    stopScan(); drop(lost = link == Link.CONNECTED); cancelPlan()
                }
                BluetoothAdapter.STATE_ON -> { log("Bluetooth on"); attempt = 0; plan(800) }
            }
        }
    }

    // ---------- reconnecting ----------

    private var attempt = 0
    private val retry = Runnable { retryAt = null; reconnectNow() }

    private fun cancelPlan() { main.removeCallbacks(retry); retryAt = null }

    /** Plans the next try at the remembered laser: [first] ms for the first one, then a growing pause. */
    private fun plan(first: Long? = null) {
        cancelPlan()
        val addr = savedAddr
        if (addr == null || stopped || paused || link != Link.IDLE || adapter == null || !LaserPerms.btOn(ctx) || !LaserPerms.canConnect(ctx)) return
        val d = first ?: BACKOFF_S[minOf(attempt, BACKOFF_S.lastIndex)] * 1000L
        attempt++
        retryAt = SystemClock.uptimeMillis() + d
        main.postDelayed(retry, d)
    }

    private fun reconnectNow() {
        val addr = savedAddr ?: return
        if (link != Link.IDLE || stopped || paused) return
        if (scanning) { plan(); return }
        connect(addr, savedName, user = false)
    }

    /** The Device sheet was opened: an old scan's list and problem go; the remembered laser is tried at once. */
    fun opened() {
        if (!scanning) { found.clear(); scanned = false }
        if (link == Link.IDLE) problem = null
        kick()
    }

    /** The remembered laser is tried at once (unless "Uzish" was pressed). */
    fun kick() {
        if (savedAddr == null || stopped || paused || link != Link.IDLE) return
        attempt = 0; plan(0)
    }

    // ---------- scanning ----------

    private var leOn = false
    private val tick = object : Runnable {
        override fun run() { scanLeft -= 1; if (scanLeft <= 0) { stopScan(); scanned = true } else main.postDelayed(this, 1000) }
    }

    /** A 15 s BLE scan; lasers ("ZB…" or the SPS service) and other named devices are listed. */
    fun startScan() {
        val a = adapter ?: return
        if (scanning || paused) return
        if (!LaserPerms.btOn(ctx)) { log("scan: Bluetooth is off"); return }
        val sc = safe { a.bluetoothLeScanner } ?: run { log("scan: no BLE scanner"); problem = "lz.scanFail"; return }
        found.clear(); scanned = false; problem = null
        cancelPlan()
        try {
            sc.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), scanCb)
            leOn = true; scanning = true; scanLeft = SCAN_S
            log("=== laser scan: $SCAN_S s ===")
            main.postDelayed(tick, 1000)
        } catch (e: Exception) { log("scan failed to start: $e"); problem = "lz.scanFail" }
    }

    fun stopScan() {
        main.removeCallbacks(tick)
        if (leOn) { safe { adapter?.bluetoothLeScanner?.stopScan(scanCb) }; leOn = false }
        if (!scanning) return
        scanning = false; scanLeft = 0
        log("=== laser scan stop: ${found.values.count { it.laser }} laser(s), ${found.size} device(s) ===")
        // a remembered laser is tried again after the scan
        if (link == Link.IDLE) { attempt = 0; plan(500) }
    }

    private val scanCb = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { onMain { seen(result) } }
        override fun onBatchScanResults(results: MutableList<ScanResult>) { onMain { results.forEach { seen(it) } } }
        override fun onScanFailed(errorCode: Int) { onMain { log("scan failed: code $errorCode"); problem = "lz.scanFail"; leOn = false; stopScan() } }
    }

    private fun seen(r: ScanResult) {
        if (!scanning) return
        val d = r.device
        val name = r.scanRecord?.deviceName ?: safe { d.name }
        val sps = r.scanRecord?.serviceUuids?.any { it.uuid == Sps.SERVICE } == true
        val laser = sps || name?.trim()?.startsWith("ZB", ignoreCase = true) == true
        if (name.isNullOrBlank() && !laser) return
        val old = found[d.address]
        found[d.address] = FoundDev(d.address, name ?: old?.name, r.rssi, laser || old?.laser == true)
        if (old == null) log("found: ${name ?: "—"} ${d.address} rssi=${r.rssi}${if (laser) " (laser)" else ""}")
    }

    // ---------- connecting ----------

    private var gatt: BluetoothGatt? = null
    private val parser = JrtParser()
    private val cccdQueue = ArrayDeque<BluetoothGattCharacteristic>()
    private var cccdCur: BluetoothGattCharacteristic? = null
    private var discovered = false
    private val connectTimeout = Runnable { log("connect: no answer in ${CONNECT_S}s"); fail("lz.failed") }
    private val mtuTimeout = Runnable { gatt?.let { log("MTU: no answer"); discover(it) } }
    private val cccdTimeout = Runnable { log("CCCD: no answer in 4 s"); cccdDone(cccdCur, false) }

    /** Connects to the laser at [addr]; [user] when picked in the sheet (only then is a failure said). */
    fun connect(addr: String, name: String?, user: Boolean = true) {
        val a = adapter ?: return
        if (paused) return
        if (user) { stopped = false; attempt = 0 }
        stopScan(); cancelPlan(); close()
        val d = try { a.getRemoteDevice(addr) } catch (e: Exception) { log("connect: bad address $addr: $e"); return }
        problem = null; userConnect = user
        link = Link.CONNECTING; linkAddr = addr; linkName = name ?: found[addr]?.name
        discovered = false; parser.reset()
        log("=== connect ${linkName ?: "—"} $addr (${if (user) "picked" else "reconnect"}) ===")
        gatt = safe { d.connectGatt(ctx, false, gattCb, BluetoothDevice.TRANSPORT_LE) }
        if (gatt == null) { fail("lz.failed"); return }
        main.postDelayed(connectTimeout, CONNECT_S * 1000L)
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
                log("GATT: ${if (newState == BluetoothProfile.STATE_CONNECTED) "connected" else if (newState == BluetoothProfile.STATE_DISCONNECTED) "disconnected" else "state $newState"} (status $status)")
                if (g != gatt) { if (newState == BluetoothProfile.STATE_DISCONNECTED) safe { g.close() }; return@onMain }
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    val asked = safe { g.requestMtu(247) } == true
                    if (asked) main.postDelayed(mtuTimeout, 4000) else discover(g)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    if (link == Link.CONNECTED) drop(lost = true) else fail("lz.failed")
                }
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) { onMain { log("MTU: $mtu (status $status)"); discover(g) } }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) { onMain { if (g == gatt) servicesFound(g, status) } }

        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
            onMain { if (g == gatt && d.characteristic == cccdCur) cccdDone(d.characteristic, status == BluetoothGatt.GATT_SUCCESS) }
        }

        @Deprecated("Android 12 and older")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") val v = c.value?.copyOf() ?: ByteArray(0)
            onMain { if (g == gatt) data(c.uuid, v) }
        }
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            val v = value.copyOf(); onMain { if (g == gatt) data(c.uuid, v) }
        }
    }

    private fun servicesFound(g: BluetoothGatt, status: Int) {
        val svc = g.getService(Sps.SERVICE)
        log("services (status $status): ${g.services.size}; SPS ${if (svc != null) "found" else "MISSING"}")
        if (svc == null) { fail("lz.notLaser"); return }
        cccdQueue.clear()
        listOf(Sps.TX, Sps.FLOW).mapNotNull { svc.getCharacteristic(it) }
            .filter { it.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0 }
            .forEach { cccdQueue.addLast(it) }
        if (cccdQueue.firstOrNull()?.uuid != Sps.TX) { log("SPS TX cannot notify"); fail("lz.notLaser"); return }
        nextCccd()
    }

    private fun nextCccd() {
        main.removeCallbacks(cccdTimeout)
        val g = gatt ?: return
        val c = cccdQueue.removeFirstOrNull()
        cccdCur = c
        if (c == null) return
        if (enableCccd(g, c)) main.postDelayed(cccdTimeout, 4000) else main.post { cccdDone(c, false) }
    }

    private fun cccdDone(c: BluetoothGattCharacteristic?, ok: Boolean) {
        main.removeCallbacks(cccdTimeout)
        if (c == null) return
        cccdCur = null
        log("  notifications on ${if (c.uuid == Sps.TX) "TX" else "flow"}: ${if (ok) "on" else "FAILED"}")
        if (c.uuid == Sps.TX) {
            if (!ok) { fail("lz.failed"); return }
            ready()
        }
        nextCccd()
    }

    /** The only write ever made to the laser: the CCCD value that turns notifications (or indications) on. */
    private fun enableCccd(g: BluetoothGatt, c: BluetoothGattCharacteristic): Boolean {
        safe { g.setCharacteristicNotification(c, true) }
        val d = c.getDescriptor(Sps.CCCD) ?: return false
        check(d.uuid == Sps.CCCD)
        val v = if (c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE else BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        return safe {
            if (Build.VERSION.SDK_INT >= 33) g.writeDescriptor(d, v) == BluetoothStatusCodes.SUCCESS
            else { @Suppress("DEPRECATION") d.value = v; @Suppress("DEPRECATION") g.writeDescriptor(d) }
        } == true
    }

    private fun ready() {
        main.removeCallbacks(connectTimeout)
        val addr = linkAddr ?: return
        val name = linkName ?: savedName ?: "ZB-08"
        val user = userConnect
        link = Link.CONNECTED; linkName = name; attempt = 0; stopped = false; problem = null; userConnect = false
        settings?.setLaserDevice(addr, name)
        log("=== ready: $name $addr; measure with the laser's own button ===")
        onEvent?.invoke("connected", name, user)
    }

    private fun data(uuid: UUID, b: ByteArray) {
        if (uuid != Sps.TX) { log("data on ${if (uuid == Sps.FLOW) "flow" else uuid.toString()}: ${JrtParser.hex(b)}"); return }
        val now = SystemClock.uptimeMillis()
        for (e in parser.feed(b, now)) when (e) {
            is JrtEvent.Reading -> {
                if (e.mm <= 0) { log("JRT ${e.hex} → 0 mm (q ${e.quality}): ignored"); continue }
                log("JRT ${e.hex} → ${e.mm} mm (q ${e.quality})")
                onReading?.invoke(LaserReading(e.mm, e.quality, System.currentTimeMillis()))
            }
            is JrtEvent.Other -> log("JRT ${e.hex} → register 0x%04X, not a reading: ignored".format(e.reg))
            is JrtEvent.BadChecksum -> log("JRT ${e.hex} → bad checksum: ignored")
            is JrtEvent.Skipped -> log("JRT skipped bytes: ${e.hex}")
        }
    }

    // ---------- ending ----------

    private fun close() {
        main.removeCallbacks(connectTimeout); main.removeCallbacks(mtuTimeout); main.removeCallbacks(cccdTimeout)
        cccdQueue.clear(); cccdCur = null
        gatt?.let { g -> safe { g.disconnect() }; safe { g.close() } }
        gatt = null
    }

    /** A try did not reach "ready": said only when the builder picked the laser; the remembered one is tried again later. */
    private fun fail(key: String) {
        val user = userConnect
        log("connect failed ($key)")
        close()
        link = Link.IDLE; userConnect = false
        if (user || key == "lz.notLaser") problem = key
        if (key != "lz.notLaser" && linkAddr == savedAddr) plan()
    }

    /** The link went away: [lost] when it was up (said to the builder), then the remembered laser is tried again. */
    private fun drop(lost: Boolean) {
        close()
        val was = link
        link = Link.IDLE; userConnect = false
        if (lost && was == Link.CONNECTED) { log("=== link lost ==="); onEvent?.invoke("lost", linkName, false); attempt = 0; plan(1000) }
    }

    /** "Uzish": disconnects and stops reconnecting by itself for now. */
    fun disconnect() {
        log("=== disconnect (Uzish) ===")
        stopped = true; cancelPlan(); close()
        link = Link.IDLE; userConnect = false
    }

    /** "Unutish": disconnects and forgets the laser. */
    fun forget() {
        log("=== forget ${savedName ?: "—"} ${savedAddr ?: ""} ===")
        cancelPlan(); close()
        link = Link.IDLE; userConnect = false; linkAddr = null; linkName = null; stopped = false; problem = null
        settings?.setLaserDevice(null, null)
    }

    /** The test page takes Bluetooth over (its own scan and connection); [resume] gives it back. */
    fun pause() {
        if (paused) return
        log("=== real laser paused for the test page ===")
        stopScan(); cancelPlan(); close()
        link = Link.IDLE; userConnect = false; paused = true
    }

    fun resume() {
        if (!paused) return
        paused = false
        log("=== real laser resumed ===")
        attempt = 0; plan(600)
    }

    companion object {
        const val SCAN_S = 15
        private const val CONNECT_S = 20
        private val BACKOFF_S = longArrayOf(2, 4, 8, 15, 30, 45, 60)
        @Volatile private var one: RealLaser? = null
        fun get(ctx: Context): RealLaser = one ?: synchronized(this) { one ?: RealLaser(ctx.applicationContext).also { one = it } }
    }
}
