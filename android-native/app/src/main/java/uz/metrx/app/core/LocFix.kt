package uz.metrx.app.core

/*
 * The pure rules of "Joylashuvni aniqlash" (GPS fix, 27 Oct 2026): which fix is the best so far, when the search stops
 * by itself and when the phone's last known location may be shown as a first value. No Android types, so they are
 * unit-tested (LocFixTest).
 */

/**
 * One reading. [acc] is the radius in metres; [atMs] is when it was measured on the phone's boot clock
 * (SystemClock.elapsedRealtime), so ages don't jump when the wall clock is set; [cached] marks the phone's last
 * known location (shown first, but labelled and always replaced by a live reading).
 */
data class Fix(val lat: Double, val lng: Double, val acc: Float, val atMs: Long, val cached: Boolean = false)

object LocFix {
    /** Stop by itself once a live fix is this good. */
    const val GOOD_M = 20f
    /** The search gives up (keeping the best fix, if any) after this long. */
    const val MAX_MS = 30_000L
    /** A last known location is used only when it is younger than this… */
    const val CACHE_AGE_MS = 120_000L
    /** …and at least this accurate. */
    const val CACHE_ACC_M = 100f
    /** A reading without an accuracy counts as this rough. */
    const val UNKNOWN_ACC_M = 500f

    /** Whether the last known location [f] may be shown at [nowMs] (same clock as [Fix.atMs]). */
    fun freshEnough(f: Fix, nowMs: Long): Boolean {
        val age = nowMs - f.atMs
        return age in 0 until CACHE_AGE_MS && f.acc > 0f && f.acc <= CACHE_ACC_M
    }

    /**
     * The better of the best so far [cur] and a new reading [new]: a live reading always beats a cached one (it is
     * where the phone is now); between two of a kind the more accurate wins, and the newer one on a tie.
     */
    fun better(cur: Fix?, new: Fix): Fix {
        if (cur == null) return new
        if (cur.cached != new.cached) return if (new.cached) cur else new
        if (new.acc < cur.acc) return new
        if (new.acc == cur.acc && new.atMs >= cur.atMs) return new
        return cur
    }

    enum class Step { WAIT, DONE, FAIL }

    /**
     * What the search does after [elapsedMs] with the best fix [best]: done at ±[GOOD_M] m or better (a live fix;
     * with approximate location only, [precise] false, the first live fix, as it won't get better), done with the
     * best fix after [MAX_MS], failed after [MAX_MS] only if there is no fix at all; otherwise keep waiting.
     */
    fun step(best: Fix?, elapsedMs: Long, precise: Boolean = true): Step = when {
        best != null && !best.cached && (best.acc <= GOOD_M || !precise) -> Step.DONE
        elapsedMs >= MAX_MS -> if (best != null) Step.DONE else Step.FAIL
        else -> Step.WAIT
    }

    /** The metres shown and saved ("±X m"): whole metres, at least 1. */
    fun metres(acc: Float): Int = maxOf(1, Math.round(acc))
}
