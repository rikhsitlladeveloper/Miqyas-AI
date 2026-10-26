package uz.metrx.app.ui.ux

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View

/** The three haptic kinds of the UX upgrades (§10). */
enum class Hap {
    /** A step, an undo, a switch. */
    TICK,
    /** A laser or voice value, a quote sent. */
    CONFIRM,
    /** An error. */
    WARN
}

/**
 * The phone's own haptic patterns, no sound: CONFIRM and REJECT on Android 11+, the closest older ones below (minSdk 26).
 * The app's switch (Profile → "Tebranish") is checked by the caller (App.haptic).
 */
object Haptics {
    fun play(v: View, kind: Hap) {
        val c = when (kind) {
            Hap.TICK -> HapticFeedbackConstants.CLOCK_TICK
            Hap.CONFIRM -> if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY
            Hap.WARN -> if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
        }
        runCatching { v.performHapticFeedback(c) }
    }
}
