package uz.metrx.app.laser

import kotlin.math.min

/*
 * The pure rules behind the laser's radar page (ui/main/LaserRadar.kt) and RealLaser: where a laser sits on the radar,
 * what a GATT disconnect means, when a run of failures becomes "busy" or "3 tries", how long to wait before the next
 * try, when a scan may start. No Android here (unit-tested in LinkRulesTest).
 */

/** Why a connection the builder asked for did not come up (or went away): each has its own card on the radar page. */
enum class LaserFail {
    /** No answer within [LinkRules.ANSWER_MS] (laser off or too far). */
    TIMEOUT,
    /** The laser drops the link at once, again and again: most likely another phone holds it. */
    BUSY,
    /** Connected, but it has no SPS service: not a laser METRX can read. */
    NOT_LASER,
    /** Bluetooth was turned off while connecting. */
    BT_OFF,
    /** Android refused the Bluetooth permission. */
    PERMISSION
}

/** What one GATT disconnect during a try means. */
enum class DropKind {
    /** The link was up and ready: it went away (laser off or out of range). */
    LOST,
    /** Dropped right after "connected": counted towards [LaserFail.BUSY]. */
    QUICK,
    /** Refused before any connection (a 133/8/257 status): tried once more quietly, then "no answer", never "busy". */
    REFUSED,
    /** Anything else before the link was ready: treated like no answer. */
    NO_ANSWER
}

/** What one service discovery means. */
enum class Discovery {
    /** The SPS service with a TX characteristic that can notify: the laser. */
    OK,
    /** The discovery itself failed (a GATT error, or no services at all): the link is tried again, the device is not judged. */
    RETRY,
    /** A discovery that worked, without the SPS service: not a laser METRX can read. */
    NOT_LASER
}

object LinkRules {
    /** A try that has had no GATT "connected" for this long has failed (the founder's laser answers in ~0.2 s). */
    const val ANSWER_MS = 10_000L
    /** A drop this soon after "connected" is a quick drop. */
    const val QUICK_MS = 2_000L
    /** GATT statuses Android gives when the other side refuses at once: 133 GATT_ERROR, 8 CONN_TIMEOUT, 257 FAILURE. */
    val QUICK_STATUSES = setOf(133, 8, 257)
    /** This many quick drops in one try: "busy" (the first one is retried by itself). */
    const val BUSY_AFTER = 2
    /** This many failed tries in a row: the help list instead of the single reason. */
    const val MANY_AFTER = 3
    /** The radar page's countdown after the link is lost, before the app connects again by itself. */
    const val LOST_WAIT_MS = 4_000L
    /** The pause before a quick drop is retried. */
    const val QUICK_RETRY_MS = 800L
    /** The pauses between background reconnects, growing (seconds). */
    private val BACKOFF_S = longArrayOf(2, 4, 8, 15, 30, 45, 60)

    fun drop(status: Int, ready: Boolean, gattUp: Boolean, msSinceUp: Long): DropKind = when {
        ready -> DropKind.LOST
        gattUp && msSinceUp in 0..QUICK_MS -> DropKind.QUICK
        !gattUp && status in QUICK_STATUSES -> DropKind.REFUSED
        else -> DropKind.NO_ANSWER
    }

    /** Quiet retries in one try after a refusal before "connected" or a failed service discovery (then "no answer"). */
    const val SOFT_RETRIES = 1

    /** Whether soft failure number [n] (1 first) of a try is retried quietly; a background try is not (its plan tries again). */
    fun softRetry(n: Int, user: Boolean) = user && n <= SOFT_RETRIES

    /** A service discovery's [status] (0 = GATT_SUCCESS), how many [services] came, whether [sps] (with TX that notifies) is there. */
    fun discovery(status: Int, services: Int, sps: Boolean): Discovery = when {
        status != 0 || services <= 0 -> Discovery.RETRY
        sps -> Discovery.OK
        else -> Discovery.NOT_LASER
    }

    /** Background tries in a row at the remembered laser without an answer before the app stops and scans for it instead. */
    const val BG_TRIES = 5
    /** With the radar page open: after this many, its "didn't answer" card shows (and the tries stop). */
    const val RADAR_BG_TRIES = 3

    fun bgCapped(fails: Int, radarOpen: Boolean) = fails >= if (radarOpen) RADAR_BG_TRIES else BG_TRIES

    /** While scanning for the remembered laser: this one is it (the same address, or the same name at a new address). */
    fun sameLaser(savedAddr: String?, savedName: String?, addr: String, name: String?): Boolean =
        addr.equals(savedAddr, ignoreCase = true) || (!savedName.isNullOrBlank() && name != null && name.trim().equals(savedName.trim(), ignoreCase = true))

    fun isBusy(quickDrops: Int) = quickDrops >= BUSY_AFTER

    /** After [streak] failed tries in a row, the help list replaces the fixable reasons (not "not a laser" and the like). */
    fun showMany(fail: LaserFail, streak: Int) = (fail == LaserFail.TIMEOUT || fail == LaserFail.BUSY) && streak >= MANY_AFTER

    /** The pause before background try number [attempt] (0 first); the radar page, open, never waits longer than its countdown. */
    fun backoffMs(attempt: Int, radarOpen: Boolean): Long {
        val d = BACKOFF_S[attempt.coerceIn(0, BACKOFF_S.lastIndex)] * 1000L
        return if (radarOpen) min(d, LOST_WAIT_MS) else d
    }

    /** Whole seconds left until [at] (rounded up) and how much of [total] has passed (0…1). */
    fun countdown(now: Long, at: Long, total: Long): Pair<Int, Float> {
        val left = (at - now).coerceAtLeast(0)
        val s = ((left + 999) / 1000).toInt()
        val p = if (total <= 0) 1f else (1f - left.toFloat() / total).coerceIn(0f, 1f)
        return s to p
    }
}

/**
 * When a BLE scan may start: at most [MAX] starts in [WINDOW_MS] (Android refuses the 5th in 30 s with error 6), and not
 * for [FAIL_WAIT_MS] after a scan failed (the problem is shown meanwhile). Times are uptime ms.
 */
class ScanGate {
    private val starts = ArrayDeque<Long>()
    var failedAt: Long? = null; private set

    /** How long until a scan may start (0: now). */
    fun waitMs(now: Long): Long {
        while (starts.isNotEmpty() && now - starts.first() >= WINDOW_MS) starts.removeFirst()
        val f = failedAt?.let { (it + FAIL_WAIT_MS - now).coerceAtLeast(0) } ?: 0L
        val t = if (starts.size >= MAX) (starts.first() + WINDOW_MS - now).coerceAtLeast(0) else 0L
        return maxOf(f, t)
    }

    fun started(now: Long) { starts.addLast(now) }
    fun failed(now: Long) { failedAt = now }
    /** Bluetooth was turned off and on: a failed scan may be tried again at once. */
    fun clearFail() { failedAt = null }

    companion object {
        const val MAX = 4
        const val WINDOW_MS = 30_000L
        const val FAIL_WAIT_MS = 30_000L
    }
}

/** Where a laser sits on the radar: angle from its address (stable), distance from its signal. */
object RadarMath {
    /** −45 dBm sits nearest the centre, −90 dBm at the edge. */
    const val NEAR = -45f
    const val FAR = -90f
    /** Distance from the centre as a part of the radar's radius (just outside the phone disc … the outer ring). */
    const val R_MIN = .52f
    const val R_MAX = .92f
    /** A laser not heard for this long leaves the radar. */
    const val STALE_MS = 20_000L

    fun radius(rssi: Float): Float {
        val t = ((NEAR - rssi) / (NEAR - FAR)).coerceIn(0f, 1f)
        return R_MIN + t * (R_MAX - R_MIN)
    }

    /** Degrees 0…360 (0 = right, clockwise on screen), the same for one address every time (FNV-1a). */
    fun angle(address: String): Float {
        var h = 0x811C9DC5.toInt()
        for (c in address.uppercase()) { h = h xor c.code; h *= 0x01000193 }
        return ((h.toLong() and 0xFFFFFFFFL) % 3600L) / 10f
    }

    /** Signal bars 1…4. */
    fun bars(rssi: Int): Int = when { rssi > -55 -> 4; rssi > -65 -> 3; rssi > -78 -> 2; else -> 1 }

    /** The word for the signal (string key). */
    fun qualityKey(rssi: Int): String = when (bars(rssi)) { 4, 3 -> "lr.sigGood"; 2 -> "lr.sigOk"; else -> "lr.sigWeak" }

    /** A smoothed signal: each new reading moves the old value by [k] (the first one is taken as it is). */
    fun smooth(prev: Float?, next: Int, k: Float = .35f): Float = if (prev == null) next.toFloat() else prev + (next - prev) * k

    fun stale(seenAt: Long, now: Long) = seenAt > 0 && now - seenAt > STALE_MS

    /** A device's list entry is redrawn at most this often… */
    const val PUBLISH_MS = 500L
    /** …unless its smoothed signal moved this much (dB), or it is new, renamed or turned out (not) a laser. */
    const val PUBLISH_DB = 1.5f

    /** Whether the newest advert [next] should replace the entry the radar shows ([shown]) now. */
    fun publish(shown: FoundDev?, next: FoundDev, now: Long): Boolean =
        shown == null || shown.name != next.name || shown.laser != next.laser || now - shown.seen >= PUBLISH_MS ||
            kotlin.math.abs(next.avg - shown.avg) >= PUBLISH_DB
}
