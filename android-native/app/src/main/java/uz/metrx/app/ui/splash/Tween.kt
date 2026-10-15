package uz.metrx.app.ui.splash

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.pow

/** GSAP's eases, so the timeline reads the same as the artifact (power1 = quad, power2 = cubic, power3 = quart). */
object Ease {
    val none: (Float) -> Float = { it }
    val p1In: (Float) -> Float = { it * it }
    val p1Out: (Float) -> Float = { 1 - (1 - it) * (1 - it) }
    val p1InOut: (Float) -> Float = { if (it < .5f) 2 * it * it else 1 - (-2 * it + 2).pow(2) / 2 }
    val p2In: (Float) -> Float = { it * it * it }
    val p2Out: (Float) -> Float = { 1 - (1 - it).pow(3) }
    val p3In: (Float) -> Float = { it.pow(4) }
    val p3Out: (Float) -> Float = { 1 - (1 - it).pow(4) }
    val p3InOut: (Float) -> Float = { if (it < .5f) 8 * it.pow(4) else 1 - (-2 * it + 2).pow(4) / 2 }
    val sineInOut: (Float) -> Float = { -(cos(PI * it).toFloat() - 1) / 2 }
    val expoOut: (Float) -> Float = { if (it >= 1f) 1f else 1 - 2f.pow(-10 * it) }
    val expoInOut: (Float) -> Float = {
        when {
            it <= 0f -> 0f
            it >= 1f -> 1f
            it < .5f -> 2f.pow(20 * it - 10) / 2
            else -> (2 - 2f.pow(-20 * it + 10)) / 2
        }
    }
    fun backOut(s: Float): (Float) -> Float = { val x = it - 1; 1 + (s + 1) * x * x * x + s * x * x }
}

/**
 * One animated number: a starting value and tweens that each run from wherever the value is when they start
 * (GSAP's to()), or from an explicit value (fromTo()). A zero-length tween is a set().
 */
class Track(private val init: Float) {
    private class Seg(val start: Float, val dur: Float, val from: Float?, val to: Float, val ease: (Float) -> Float)
    private val segs = ArrayList<Seg>()
    private var froms: FloatArray? = null

    fun to(start: Float, dur: Float, to: Float, ease: (Float) -> Float = Ease.p3Out) = apply { segs += Seg(start, dur, null, to, ease); froms = null }
    fun fromTo(start: Float, dur: Float, from: Float, to: Float, ease: (Float) -> Float = Ease.p3Out) = apply { segs += Seg(start, dur, from, to, ease); froms = null }
    fun set(at: Float, v: Float) = apply { segs += Seg(at, 0f, null, v, Ease.none); froms = null }

    private fun prepare(): FloatArray {
        froms?.let { return it }
        segs.sortBy { it.start }
        val f = FloatArray(segs.size)
        for (i in segs.indices) f[i] = segs[i].from ?: eval(segs[i].start, i, f)
        froms = f
        return f
    }

    private fun eval(t: Float, upto: Int, f: FloatArray): Float {
        var v = init
        for (i in 0 until upto) {
            val s = segs[i]
            if (t < s.start) break
            val p = if (s.dur <= 0f) 1f else ((t - s.start) / s.dur).coerceIn(0f, 1f)
            v = f[i] + (s.to - f[i]) * s.ease(p)
        }
        return v
    }

    operator fun invoke(t: Float): Float { val f = prepare(); return eval(t, segs.size, f) }
}
