package uz.metrx.app.ui.loc

import android.annotation.SuppressLint
import android.content.Context
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import androidx.core.location.LocationManagerCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import uz.metrx.app.core.Fix
import uz.metrx.app.core.LocFix

/*
 * Where the readings come from (GPS fix, 27 Oct 2026): Google's fused provider (GPS + Wi-Fi + cell) when Google Play
 * services are on the phone, else the phone's own GPS and network providers side by side. Each pushes the last known
 * location first (marked cached) and then live readings, about once a second, on the main thread.
 */

internal interface LocSource {
    /** Starts listening; [onError] when it can't (the caller then falls back or gives up). */
    fun start(onFix: (Fix) -> Unit, onError: () -> Unit)
    fun stop()
}

internal fun hasPlayServices(ctx: Context): Boolean =
    runCatching { GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(ctx) == ConnectionResult.SUCCESS }.getOrDefault(false)

/** Whether location is switched on in the phone's settings. */
internal fun locationOn(ctx: Context): Boolean = runCatching {
    LocationManagerCompat.isLocationEnabled(ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager)
}.getOrDefault(false)

/** The fused provider's request: high accuracy, a reading every second. */
internal fun highAccuracyRequest(): LocationRequest =
    LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L).setMinUpdateIntervalMillis(500L).setWaitForAccurateLocation(false).build()

internal fun android.location.Location.toFix(cached: Boolean): Fix {
    val at = elapsedRealtimeNanos / 1_000_000L
    return Fix(latitude, longitude, if (hasAccuracy() && accuracy > 0f) accuracy else LocFix.UNKNOWN_ACC_M,
        // a live reading without its time counts as now; a cached one as too old to use
        if (at > 0L) at else if (cached) 0L else SystemClock.elapsedRealtime(), cached)
}

internal class FusedSource(ctx: Context) : LocSource {
    private val client = LocationServices.getFusedLocationProviderClient(ctx)
    private var cb: LocationCallback? = null

    @SuppressLint("MissingPermission")
    override fun start(onFix: (Fix) -> Unit, onError: () -> Unit) {
        val c = object : LocationCallback() {
            override fun onLocationResult(r: LocationResult) { if (cb === this) r.locations.forEach { onFix(it.toFix(false)) } }
        }
        cb = c
        runCatching {
            client.lastLocation.addOnSuccessListener { l -> if (l != null && cb === c) onFix(l.toFix(true)) }
            client.requestLocationUpdates(highAccuracyRequest(), c, Looper.getMainLooper())
                .addOnFailureListener { if (cb === c) { stop(); onError() } }
        }.onFailure { if (cb === c) { stop(); onError() } }
    }

    override fun stop() { cb?.let { c -> runCatching { client.removeLocationUpdates(c) } }; cb = null }
}

/** Without Google Play services: the GPS and network providers at once; the caller keeps the better reading. */
internal class PlatformSource(ctx: Context) : LocSource {
    private val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val listeners = mutableListOf<LocationListener>()

    @SuppressLint("MissingPermission")
    override fun start(onFix: (Fix) -> Unit, onError: () -> Unit) {
        for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            if (!runCatching { lm.isProviderEnabled(p) }.getOrDefault(false)) continue
            // GPS needs the precise permission: with approximate only it throws and the network provider still runs
            runCatching { lm.getLastKnownLocation(p) }.getOrNull()?.let { onFix(it.toFix(true)) }
            // all four methods, as Androids before 11 call them all
            val li = object : LocationListener {
                override fun onLocationChanged(location: android.location.Location) { if (this in listeners) onFix(location.toFix(false)) }
                @Deprecated("Deprecated in Java") override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }
            runCatching { lm.requestLocationUpdates(p, 1000L, 0f, li, Looper.getMainLooper()); listeners += li }
        }
        if (listeners.isEmpty()) onError()
    }

    override fun stop() { listeners.toList().forEach { runCatching { lm.removeUpdates(it) } }; listeners.clear() }
}
