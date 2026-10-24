package uz.metrx.app.laser

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.mutableStateListOf
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

const val LASER_TAG = "METRX-LASER"

/**
 * The laser's log, shared by the real laser (RealLaser) and the "Lazer sinovi" page: kept while the app runs, every
 * line also in logcat (`adb logcat -s METRX-LASER`).
 */
object LaserLog {
    val lines = mutableStateListOf<String>()
    private val main = Handler(Looper.getMainLooper())
    private val fmt = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun add(msg: String) {
        val line = synchronized(fmt) { fmt.format(Date()) } + "  " + msg
        Log.i(LASER_TAG, msg)
        if (Looper.myLooper() == Looper.getMainLooper()) put(line) else main.post { put(line) }
    }

    private fun put(line: String) {
        lines.add(line)
        if (lines.size > 6000) lines.removeRange(0, lines.size - 5000)
    }

    fun text(): String = lines.joinToString("\n")
    fun clear() { lines.clear(); Log.i(LASER_TAG, "----- log cleared -----") }
}

/**
 * What Bluetooth needs on this phone, shared by the Device sheet and the test page. Scanning: location up to Android 11
 * (and location services on); from Android 12 BLUETOOTH_SCAN and BLUETOOTH_CONNECT, plus location, since the manifest
 * does not say neverForLocation. Connecting to a known laser needs only BLUETOOTH_CONNECT (nothing up to Android 11).
 */
object LaserPerms {
    fun needed(): List<String> =
        if (Build.VERSION.SDK_INT >= 31) listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.ACCESS_FINE_LOCATION)
        else listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)

    fun missing(ctx: Context) = needed().filter { ContextCompat.checkSelfPermission(ctx, it) != PackageManager.PERMISSION_GRANTED }

    fun canConnect(ctx: Context) = Build.VERSION.SDK_INT < 31 || ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    fun hasBt(ctx: Context) = ctx.getSystemService(BluetoothManager::class.java)?.adapter != null

    fun btOn(ctx: Context) = try { ctx.getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled == true } catch (_: Exception) { false }

    fun locOn(ctx: Context) = ctx.getSystemService(LocationManager::class.java)?.let { LocationManagerCompat.isLocationEnabled(it) } ?: false

    fun open(ctx: Context, intent: Intent) {
        try { ctx.startActivity(intent) } catch (e: Exception) { LaserLog.add("could not open settings: $e") }
    }
}
