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
 * button. The last laser's address is kept in Settings; it is connected again by itself when the app starts or comes
 * back to the front, after the link drops and when Bluetooth comes back on, with a growing pause between tries. After
 * [LinkRules.BG_TRIES] tries without an answer it stops and scans once for the laser (at a new address too). In the
 * background nothing is scanned or tried, and the link is let go after [BG_GRACE_MS].
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

/**
 * A device the scan saw: [laser] when its name starts with "ZB" or it shows the SPS service. [avg] is the smoothed
 * signal (the radar's distance), [seen] when it was last heard (uptime ms).
 */
data class FoundDev(val address: String, val name: String?, val rssi: Int, val laser: Boolean, val avg: Float = rssi.toFloat(), val seen: Long = 0L)

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

    // ---- for the radar page (ui/main/LaserRadar.kt) ----
    /** The radar page is open: the link-lost countdown is its own (4 s) and background tries wait at most that long. */
    var radar = false
    /** Why the last try the builder asked for failed (cleared by the next try, "Qidiruvga" and the like). */
    var failure by mutableStateOf<LaserFail?>(null); private set
    var failAddr by mutableStateOf<String?>(null); private set
    var failName by mutableStateOf<String?>(null); private set
    /** +1 for every new failure (the page shakes, buzzes and draws the snapped line once per failure). */
    var failSeq by mutableStateOf(0); private set
    /** Failed tries in a row at [failAddr] (3 → the help list); a ready link or another laser starts it again. */
    var failStreak by mutableStateOf(0); private set
    /** +1 every time a ready link goes away. */
    var lostSeq by mutableStateOf(0); private set
    /** How long the planned reconnect waits in all (ms), for the countdown's progress bar. */
    var retryTotal by mutableStateOf(0L); private set
    /** Devices that connected but had no SPS service this session: never drawn as lasers again. */
    val incompatible = mutableStateMapOf<String, Boolean>()
    /** When a scan may start (Android's 5-in-30-s limit, a pause after a failed scan). */
    val scanGate = ScanGate()

    /** The app is in the background (MainActivity onStop): no scans, no tries; the link goes after [BG_GRACE_MS]. */
    private var bg = false
    /** Background tries in a row at the remembered laser that failed ([LinkRules.bgCapped] stops them). */
    private var bgFails = 0
    /** The capped tries made way for one scan for the remembered laser ([looking] while it runs). */
    private var looked = false
    private var looking = false

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
                    stopScan()
                    // a try going on fails with its own reason (the radar page says "Bluetooth o‘chirildi")
                    if (link == Link.CONNECTING) fail("lt.btOff", LaserFail.BT_OFF)
                    drop(lost = link == Link.CONNECTED); cancelPlan()
                }
                BluetoothAdapter.STATE_ON -> {
                    log("Bluetooth on"); attempt = 0; bgFails = 0; looked = false; scanGate.clearFail()
                    // the try Bluetooth broke off goes on by itself while the radar page that said so is open ("Yoqilishi
                    // bilan ilova … ga o‘zi ulanadi"); a failure left from earlier (the Device sheet) goes, and the plan as usual
                    val a = failAddr
                    if (radar && failure == LaserFail.BT_OFF && a != null) { val n = failName; main.postDelayed({ if (radar && link == Link.IDLE && failure == LaserFail.BT_OFF) connect(a, n) }, 800) }
                    else {
                        if (failure == LaserFail.BT_OFF) { failure = null; if (problem == "lt.btOff") problem = null }
                        plan(800)
                    }
                }
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
        if (addr == null || stopped || paused || bg || link != Link.IDLE || adapter == null || !LaserPerms.btOn(ctx) || !LaserPerms.canConnect(ctx)) return
        // the radar page shows a failure card: nothing starts behind it until the builder picks what to do
        if (radar && failure != null) return
        // the remembered laser did not answer N times: no more tries by themselves (until the app, the radar or the
        // Device sheet opens again, or Bluetooth comes back); away from the radar one scan looks for it, a new address too
        if (LinkRules.bgCapped(bgFails, radar)) {
            if (!radar && !looked) { looked = true; log("remembered laser: $bgFails tries without an answer; scanning for it instead"); main.post { lookFor() } }
            return
        }
        val d = first ?: LinkRules.backoffMs(attempt, radar)
        attempt++
        retryAt = SystemClock.uptimeMillis() + d
        retryTotal = d
        main.postDelayed(retry, d)
    }

    private fun reconnectNow() {
        val addr = savedAddr ?: return
        if (link != Link.IDLE || stopped || paused || bg) return
        // the Device sheet's scan is not broken off; the radar page's (scan after scan) is
        if (scanning && !radar) { plan(); return }
        connect(addr, savedName, user = false)
    }

    /** The capped tries are over: one scan for the remembered laser; heard (at its address, or by its name), it is connected. */
    private fun lookFor() {
        if (link != Link.IDLE || scanning || bg || paused || stopped || savedAddr == null) return
        if (!LaserPerms.canScan(ctx)) { log("remembered laser: no scan permission, it waits for the next start"); return }
        startScan(look = true)
    }

    /** The Device sheet was opened: an old scan's list and problem go; the remembered laser is tried at once. */
    fun opened() {
        if (!scanning) { clearFound(); scanned = false }
        if (link == Link.IDLE) problem = null
        kick()
    }

    /** The remembered laser is tried at once (unless "Uzish" was pressed); the count of tries without an answer starts again. */
    fun kick() {
        if (savedAddr == null || stopped || paused || bg || link != Link.IDLE) return
        attempt = 0; bgFails = 0; looked = false; plan(0)
    }

    // ---------- the app in the background ----------

    private val letGo = Runnable {
        if (bg && link != Link.IDLE) { log("=== still in the background: the link is let go ==="); close(); link = Link.IDLE; userConnect = false }
    }

    /** The app went to the background (MainActivity onStop): scans and tries stop at once, a ready link after [BG_GRACE_MS]. */
    fun background() {
        if (bg) return
        bg = true
        log("=== app in the background: no scans or tries ===")
        stopScan(); cancelPlan()
        if (link == Link.CONNECTING) { close(); link = Link.IDLE; userConnect = false }
        main.postDelayed(letGo, BG_GRACE_MS)
    }

    /** The app is in front again (onStart): the remembered laser is tried at once. */
    fun foreground() {
        if (!bg) return
        bg = false
        main.removeCallbacks(letGo)
        log("=== app in the foreground ===")
        kick()
    }

    // ---------- scanning ----------

    private var leOn = false
    /** Every device's newest smoothed advert; [found] (what the pages draw) gets it at most every [RadarMath.PUBLISH_MS]. */
    private val raw = HashMap<String, FoundDev>()
    private var gateLogged = 0L

    private fun clearFound() { found.clear(); raw.clear() }
    private val tick = object : Runnable {
        override fun run() { scanLeft -= 1; if (scanLeft <= 0) { stopScan(); scanned = true } else main.postDelayed(this, 1000) }
    }

    /**
     * A 15 s BLE scan; lasers ("ZB…" or the SPS service) and other named devices are listed. [keep]: the list is kept
     * (the radar page starts scan after scan; a device not heard for a while leaves the radar by itself). [look]: the scan
     * for the remembered laser after its capped tries. Not more than 4 starts in 30 s, and none for 30 s after a failure.
     */
    fun startScan(keep: Boolean = false, look: Boolean = false) {
        val a = adapter ?: return
        if (scanning || paused || bg) return
        if (!LaserPerms.btOn(ctx)) { log("scan: Bluetooth is off"); return }
        if (!LaserPerms.canScan(ctx)) { log("scan: permission missing"); return }
        val now = SystemClock.uptimeMillis()
        val wait = scanGate.waitMs(now)
        if (wait > 0) {
            if (now >= gateLogged) { gateLogged = now + wait; log("scan: waits ${(wait + 999) / 1000} s (${if (problem == "lz.scanFail") "the last one failed" else "Android allows 5 starts in 30 s"})") }
            return
        }
        val sc = safe { a.bluetoothLeScanner } ?: run { log("scan: no BLE scanner"); problem = "lz.scanFail"; scanGate.failed(now); return }
        if (!keep) clearFound()
        scanned = false; problem = null
        // the Device sheet's scan has Bluetooth to itself; the radar page's goes on beside the planned tries
        if (!radar) cancelPlan()
        try {
            sc.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), scanCb)
            scanGate.started(now)
            leOn = true; scanning = true; scanLeft = SCAN_S; looking = look
            log("=== laser scan: $SCAN_S s${if (look) " (looking for the remembered laser)" else ""} ===")
            main.postDelayed(tick, 1000)
        } catch (e: Exception) { log("scan failed to start: $e"); problem = "lz.scanFail"; scanGate.failed(now) }
    }

    fun stopScan() {
        main.removeCallbacks(tick)
        if (leOn) { safe { adapter?.bluetoothLeScanner?.stopScan(scanCb) }; leOn = false }
        looking = false
        if (!scanning) return
        scanning = false; scanLeft = 0
        log("=== laser scan stop: ${found.values.count { it.laser }} laser(s), ${found.size} device(s) ===")
        // a remembered laser is tried again after the scan
        if (link == Link.IDLE) { attempt = 0; plan(500) }
    }

    private val scanCb = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { onMain { seen(result) } }
        override fun onBatchScanResults(results: MutableList<ScanResult>) { onMain { results.forEach { seen(it) } } }
        // the next start waits 30 s (a failing scan is not started again every moment); the pages say why meanwhile
        override fun onScanFailed(errorCode: Int) { onMain { log("scan failed: code $errorCode"); problem = "lz.scanFail"; scanGate.failed(SystemClock.uptimeMillis()); leOn = false; stopScan() } }
    }

    private fun seen(r: ScanResult) {
        if (!scanning) return
        val d = r.device
        val name = r.scanRecord?.deviceName ?: safe { d.name }
        val sps = r.scanRecord?.serviceUuids?.any { it.uuid == Sps.SERVICE } == true
        val laser = (sps || name?.trim()?.startsWith("ZB", ignoreCase = true) == true) && incompatible[d.address] != true
        if (name.isNullOrBlank() && !laser) return
        val now = SystemClock.uptimeMillis()
        val old = raw[d.address]
        val dev = FoundDev(d.address, name ?: old?.name, r.rssi, laser || (old?.laser == true && incompatible[d.address] != true),
            RadarMath.smooth(old?.avg, r.rssi), now)
        raw[d.address] = dev
        // the pages are redrawn at most twice a second per device (or when its signal really moved)
        if (RadarMath.publish(found[d.address], dev, now)) found[d.address] = dev
        if (old == null) log("found: ${name ?: "—"} ${d.address} rssi=${r.rssi}${if (laser) " (laser)" else ""}")
        if (looking && dev.laser && link == Link.IDLE && LinkRules.sameLaser(savedAddr, savedName, d.address, dev.name)) {
            looking = false
            log("remembered laser heard${if (!d.address.equals(savedAddr, true)) " at a new address" else ""}: connecting")
            connect(d.address, dev.name ?: savedName, user = false)
        }
    }

    // ---------- connecting ----------

    private var gatt: BluetoothGatt? = null
    private val parser = JrtParser()
    private val cccdQueue = ArrayDeque<BluetoothGattCharacteristic>()
    private var cccdCur: BluetoothGattCharacteristic? = null
    private var discovered = false
    private val connectTimeout = Runnable { log("connect: not ready in ${CONNECT_S}s"); fail("lz.failed", LaserFail.TIMEOUT) }
    /** No GATT "connected" at all in [LinkRules.ANSWER_MS]: the laser is off or too far. */
    private val answerTimeout = Runnable { log("connect: no answer in ${LinkRules.ANSWER_MS / 1000}s"); fail("lz.failed", LaserFail.TIMEOUT) }
    private val mtuTimeout = Runnable { gatt?.let { log("MTU: no answer"); discover(it) } }
    private val cccdTimeout = Runnable { log("CCCD: no answer in 4 s"); cccdDone(cccdCur, false) }
    /** When this try's GATT said "connected" (uptime ms), 0 before. */
    private var gattUpAt = 0L
    /** Quick drops in this try (two → "busy"). */
    private var quickDrops = 0
    /** Quiet retries in this try after a refusal before "connected" or a failed service discovery. */
    private var softFails = 0
    private val quickRetry = Runnable { val a = linkAddr; if (a != null && link == Link.CONNECTING) connect(a, linkName, user = userConnect, again = true) }

    /**
     * Connects to the laser at [addr]; [user] when the builder picked it (only then is a failure said). [again]: the
     * same try going on after a quick drop (the radar keeps its "Ulanmoqda" animation, the counts are kept).
     */
    fun connect(addr: String, name: String?, user: Boolean = true, again: Boolean = false) {
        val a = adapter ?: return
        if (paused) return
        // a second tap on the laser being connected (the bubble and "Ulash"): the try goes on; a background one becomes the builder's
        if (!again && link == Link.CONNECTING && linkAddr == addr) {
            if (user && !userConnect) {
                log("connect: the builder picked the laser being tried")
                if (addr != failAddr) failStreak = 0
                userConnect = true; stopped = false; attempt = 0; bgFails = 0; failure = null; problem = null
            }
            return
        }
        if (user) { stopped = false; attempt = 0; bgFails = 0; looked = false }
        if (user && !again) {
            if (addr != failAddr) failStreak = 0
            failure = null
        }
        if (!again) { quickDrops = 0; softFails = 0 }
        stopScan(); cancelPlan(); close()
        val d = try { a.getRemoteDevice(addr) } catch (e: Exception) { log("connect: bad address $addr: $e"); return }
        problem = null; userConnect = user
        // a laser at another address does not keep the last one's name
        val sameAddr = addr == linkAddr
        link = Link.CONNECTING; linkAddr = addr; linkName = name ?: found[addr]?.name ?: if (sameAddr) linkName else null
        discovered = false; parser.reset(); gattUpAt = 0L
        log("=== connect ${linkName ?: "—"} $addr (${if (again) "again after a quick drop" else if (user) "picked" else "reconnect"}) ===")
        if (!LaserPerms.canConnect(ctx)) { log("connect: BLUETOOTH_CONNECT not granted"); fail("lt.perm", LaserFail.PERMISSION); return }
        var denied = false
        gatt = try { d.connectGatt(ctx, false, gattCb, BluetoothDevice.TRANSPORT_LE) } catch (e: SecurityException) { log("permission missing: ${e.message}"); denied = true; null } catch (_: Exception) { null }
        if (gatt == null) { if (denied) fail("lt.perm", LaserFail.PERMISSION) else fail("lz.failed", LaserFail.TIMEOUT); return }
        main.postDelayed(answerTimeout, LinkRules.ANSWER_MS)
        main.postDelayed(connectTimeout, CONNECT_S * 1000L)
    }

    /** "Bekor qilish" while connecting: the try stops quietly; the remembered laser is not tried again by itself for now. */
    fun cancelConnect() {
        if (link != Link.CONNECTING) return
        log("=== connect cancelled ===")
        if (linkAddr == savedAddr) stopped = true
        close(); cancelPlan()
        link = Link.IDLE; userConnect = false
    }

    /** The failure card was answered ("Qidiruvga", "Boshqa lazerni qidirish", "Keyinroq"): it goes; the count stays. */
    fun clearFailure() { failure = null; problem = null }

    /** A quick drop: tried once more by itself; the second in one try means another phone most likely holds the laser. */
    private fun quick(status: Int) {
        quickDrops++
        log("quick drop #$quickDrops (status $status)")
        if (LinkRules.isBusy(quickDrops)) { fail("lz.failed", LaserFail.BUSY); return }
        if (!userConnect) { fail("lz.failed", LaserFail.TIMEOUT); return }
        close()
        main.postDelayed(quickRetry, LinkRules.QUICK_RETRY_MS)
    }

    /**
     * Refused before "connected" (Android 8 often says 133 at once) or a service discovery that failed: the builder's try
     * goes on once more by itself, then it is "no answer". Never "busy", never "not a laser".
     */
    private fun soft(why: String) {
        softFails++
        val again = LinkRules.softRetry(softFails, userConnect)
        log("$why: ${if (again) "trying once more" else "no answer"}")
        if (!again) { fail("lz.failed", LaserFail.TIMEOUT); return }
        close()
        main.postDelayed(quickRetry, LinkRules.QUICK_RETRY_MS)
    }

    private fun discover(g: BluetoothGatt) {
        main.removeCallbacks(mtuTimeout)
        if (discovered || g != gatt) return
        discovered = true
        val ok = safe { g.discoverServices() } == true
        log("discovering services: $ok")
        if (!ok) soft("service discovery did not start")
    }

    private val gattCb = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            onMain {
                log("GATT: ${if (newState == BluetoothProfile.STATE_CONNECTED) "connected" else if (newState == BluetoothProfile.STATE_DISCONNECTED) "disconnected" else "state $newState"} (status $status)")
                if (g != gatt) { if (newState == BluetoothProfile.STATE_DISCONNECTED) safe { g.close() }; return@onMain }
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    main.removeCallbacks(answerTimeout); gattUpAt = SystemClock.uptimeMillis()
                    val asked = safe { g.requestMtu(247) } == true
                    // Android 14+ sets the MTU itself and may not answer this one: discovery waits 1 s there, not 4
                    if (asked) main.postDelayed(mtuTimeout, if (Build.VERSION.SDK_INT >= 34) 1000L else 4000L) else discover(g)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    val up = gattUpAt > 0
                    when (LinkRules.drop(status, link == Link.CONNECTED, up, if (up) SystemClock.uptimeMillis() - gattUpAt else -1)) {
                        DropKind.LOST -> drop(lost = true)
                        DropKind.QUICK -> quick(status)
                        DropKind.REFUSED -> soft("refused before connecting (status $status)")
                        DropKind.NO_ANSWER -> fail("lz.failed", LaserFail.TIMEOUT)
                    }
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
        val n = safe { g.services.size } ?: 0
        val svc = if (status == BluetoothGatt.GATT_SUCCESS) safe { g.getService(Sps.SERVICE) } else null
        val txOk = svc?.getCharacteristic(Sps.TX)?.let { it.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0 } == true
        log("services (status $status): $n; SPS ${if (svc != null) "found" else "MISSING"}")
        // a discovery that failed says nothing about the device: the link is tried again (the builder's own laser is never "not a laser")
        when (LinkRules.discovery(status, n, svc != null && txOk)) {
            Discovery.RETRY -> { soft("service discovery failed"); return }
            Discovery.NOT_LASER -> { if (svc != null) log("SPS TX cannot notify"); fail("lz.notLaser", LaserFail.NOT_LASER); return }
            Discovery.OK -> {}
        }
        if (svc == null) return
        cccdQueue.clear()
        listOf(Sps.TX, Sps.FLOW).mapNotNull { svc.getCharacteristic(it) }
            .filter { it.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0 }
            .forEach { cccdQueue.addLast(it) }
        if (cccdQueue.firstOrNull()?.uuid != Sps.TX) { log("SPS TX cannot notify"); fail("lz.notLaser", LaserFail.NOT_LASER); return }
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
            if (!ok) { fail("lz.failed", LaserFail.TIMEOUT); return }
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
        val name = linkName ?: (if (addr == savedAddr) savedName else null) ?: "ZB-08"
        val user = userConnect
        link = Link.CONNECTED; linkName = name; attempt = 0; stopped = false; problem = null; userConnect = false
        failure = null; failStreak = 0; quickDrops = 0; softFails = 0; bgFails = 0; looked = false; incompatible.remove(addr)
        settings?.setLaserDevice(addr, name)
        log("=== ready: $name $addr; measure with the laser's own button ===")
        onEvent?.invoke("connected", name, user)
    }

    private fun data(uuid: UUID, b: ByteArray) {
        if (uuid != Sps.TX) { log("data on ${if (uuid == Sps.FLOW) "flow" else uuid.toString()}: ${JrtParser.hex(b)}"); return }
        val now = SystemClock.uptimeMillis()
        for (e in parser.feed(b, now)) when (e) {
            is JrtEvent.Reading -> {
                if (!JrtParser.plausible(e.mm)) { log("JRT ${e.hex} → ${e.mm} mm (q ${e.quality}): not a distance, ignored"); continue }
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
        main.removeCallbacks(connectTimeout); main.removeCallbacks(answerTimeout); main.removeCallbacks(mtuTimeout); main.removeCallbacks(cccdTimeout)
        main.removeCallbacks(quickRetry)
        cccdQueue.clear(); cccdCur = null
        gatt?.let { g -> safe { g.disconnect() }; safe { g.close() } }
        gatt = null
    }

    /**
     * A try did not reach "ready": said only when the builder picked the laser ([failure] for the radar page, [problem]
     * for the Device sheet); the remembered one is tried again later. Background tries are counted: with the radar page
     * open, the third without an answer shows its card; elsewhere the fifth ends them (LinkRules.bgCapped).
     */
    private fun fail(key: String, why: LaserFail) {
        val user = userConnect
        val addr = linkAddr
        log("connect failed ($key, $why${if (user) "" else ", background"})")
        close()
        link = Link.IDLE; userConnect = false
        if (why == LaserFail.NOT_LASER) addr?.let { incompatible[it] = true; found[it]?.let { d -> found[it] = d.copy(laser = false) }; raw.remove(it) }
        if (user) {
            problem = key
            failAddr = addr; failName = linkName; failStreak++; failure = why; failSeq++
        } else if (addr != null && addr == savedAddr && why != LaserFail.NOT_LASER) {
            bgFails++
            if (radar && why == LaserFail.TIMEOUT && LinkRules.bgCapped(bgFails, radarOpen = true)) {
                log("remembered laser: $bgFails background tries without an answer; the radar page says so")
                if (addr != failAddr) failStreak = 0
                failAddr = addr; failName = linkName; failStreak++; failure = why; failSeq++
            }
        }
        if (why != LaserFail.NOT_LASER && addr == savedAddr) plan()
    }

    /** The link went away: [lost] when it was up (said to the builder), then the remembered laser is tried again. */
    private fun drop(lost: Boolean) {
        close()
        val was = link
        link = Link.IDLE; userConnect = false
        if (lost && was == Link.CONNECTED) {
            log("=== link lost ===")
            lostSeq++
            onEvent?.invoke("lost", linkName, false); attempt = 0
            // the radar page counts down 4 s before connecting again; elsewhere it goes after 1 s, with a toast
            plan(if (radar) LinkRules.LOST_WAIT_MS else 1000)
        }
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
        failure = null; failStreak = 0; bgFails = 0; looked = false
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
        /** In the background a ready link is kept this long (a photo with the camera app, a quick look elsewhere). */
        const val BG_GRACE_MS = 15_000L
        private const val CONNECT_S = 20
        @Volatile private var one: RealLaser? = null
        fun get(ctx: Context): RealLaser = one ?: synchronized(this) { one ?: RealLaser(ctx.applicationContext).also { one = it } }
    }
}
