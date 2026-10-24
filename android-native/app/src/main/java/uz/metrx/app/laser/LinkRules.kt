package uz.metrx.app.laser

import kotlin.math.min

/*
 * The pure rules behind the laser's radar page (ui/main/LaserRadar.kt) and RealLaser: where a laser sits on the radar,
 * what a GATT disconnect means, when a run of failures becomes "busy" or "3 tries", how long to wait before the next
 * try. No Android here (unit-tested in LinkRulesTest).
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
    /** Dropped at once (right after connecting, or a 133/8/257 refusal): counted towards [LaserFail.BUSY]. */
    QUICK,
    /** Anything else before the link was ready: treated like no answer. */
    NO_ANSWER
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
        !gattUp && status in QUICK_STATUSES -> DropKind.QUICK
        else -> DropKind.NO_ANSWER
    }

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
}
