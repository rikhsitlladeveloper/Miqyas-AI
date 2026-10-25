package uz.metrx.app.ui.three

import kotlinx.coroutines.CancellationException
import uz.metrx.app.geo.V3
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.tan

/*
 * The gallery cards' pictures (modern 3D part 4, 25 Oct 2026): what a picture is made from, the memory cache and the
 * fall-back to the 2D painter. Pure Kotlin (CardCacheTest); the pictures themselves are made in Card3D.kt and kept by
 * ui/furniture/Cards.kt.
 */

/**
 * Bumped whenever the card renderer draws differently: every card on disk is made again (2: the right way up on every
 * driver, wardrobes in the modern 3D; 3: beds, tables and the rest; 5: every piece framed with the same room round it,
 * [cardFrame]; 6: room-less kupe side panels, neoclassic cornices).
 */
const val CARD_RENDER_VERSION = 6

/** A card picture's size in pixels for a quality tier: 480 × 360 (4:3) on strong phones, 320 × 240 on weak ones. */
fun cardSize(tier: Tier): Pair<Int, Int> = if (tier == Tier.HIGH) 480 to 360 else 320 to 240

/**
 * Everything a card's picture depends on: the gallery [model], its [size] (the step values, "" the usual one), the
 * order's design [style] preset, the workshop's materials and settings ([mats], a digest), the [handle], the quality
 * [tier], the [piece] itself (a digest of the piece the card shows, so a changed template makes it again) and the
 * renderer's [ver].
 */
data class CardKey(
    val model: String, val size: String, val style: String, val mats: String, val handle: String, val tier: String,
    val piece: String = "", val ver: Int = CARD_RENDER_VERSION
) {
    /** All of it in one line: the memory cache's key. */
    val id: String get() = listOf("v$ver", model, size, style, mats, handle, tier, piece).joinToString("|")

    /** The picture's file in cacheDir/cards/: a digest of [id] (a model id or a size may hold what a file name cannot). */
    val file: String get() = digest(id, 32) + ".webp"
}

/** The first [n] hex digits of [s]'s SHA-1. */
fun digest(s: String, n: Int = 16): String {
    val b = java.security.MessageDigest.getInstance("SHA-1").digest(s.toByteArray(Charsets.UTF_8))
    return b.joinToString("") { "%02x".format(it.toInt() and 0xFF) }.take(n)
}

/**
 * A digest of a piece's JSON with its random ids (the piece's, its boxes') numbered in the order they come: the same
 * model at the same size gives the same digest every time it is made.
 */
fun pieceDigest(json: String): String {
    val ids = LinkedHashSet<String>()
    Regex("\"id\":\"([^\"]*)\"").findAll(json).forEach { ids += it.groupValues[1] }
    var out = json
    ids.forEachIndexed { i, id -> if (id.isNotEmpty()) out = out.replace("\"$id\"", "\"#$i\"") }
    return digest(out)
}

/** A cache that keeps the most recently used values up to [maxBytes] (each [sizeOf] bytes); the oldest go first. */
class Lru<K : Any, V : Any>(private val maxBytes: Long, private val sizeOf: (V) -> Long) {
    private val map = LinkedHashMap<K, V>(16, .75f, true)
    var bytes = 0L; private set
    val size: Int @Synchronized get() = map.size

    @Synchronized operator fun get(k: K): V? = map[k]

    @Synchronized fun put(k: K, v: V) {
        map.put(k, v)?.let { bytes -= sizeOf(it) }
        bytes += sizeOf(v)
        // always keeps the newest one, however big
        val it = map.entries.iterator()
        while (bytes > maxBytes && map.size > 1 && it.hasNext()) {
            val e = it.next()
            if (e.key == k) continue
            bytes -= sizeOf(e.value); it.remove()
        }
    }

    @Synchronized fun clear() { map.clear(); bytes = 0 }
}

/**
 * A card's picture from the real 3D, or from the 2D painter when the 3D gives nothing or fails, so a card always
 * shows. After [maxFails] failures in a row (no lit materials, no GL) the 3D is not tried again until the app restarts.
 */
class CardFallback(private val maxFails: Int = 3) {
    @Volatile var fails = 0; private set
    val off: Boolean get() = fails >= maxFails

    /** The picture and whether it came from the 3D; null when neither gave one. */
    suspend fun <T : Any> pick(real: suspend () -> T?, paint: suspend () -> T?): Pair<T, Boolean>? {
        if (!off) {
            val r = attempt(real)
            if (r != null) { fails = 0; return r to true }
            fails++
        }
        return attempt(paint)?.let { it to false }
    }

    private suspend fun <T : Any> attempt(f: suspend () -> T?): T? = try { f() } catch (c: CancellationException) { throw c } catch (t: Throwable) { null }
}

/*
 * The cards' framing (26 Oct 2026, as the approved mockup's "Galereya kartalari"), the same rule in both apps (iPhone:
 * Furniture/CardCache.swift cardAim): the camera keeps its 3/4 angle and height, and stands as far off as makes what
 * the card shows of the piece (its boards with the floor patch under them and the walls behind them, PieceScene.cardExt)
 * take [CARD_FILL] of the card's width or height, whichever is tighter, that picture centred. Two clamps: never so far
 * that the boards alone take less than [CARD_PIECE_MIN], never so near that the card shows less than [CARD_MIN_VIEW] m
 * top to bottom at the aim (so the smallest pieces are not blown up past a nightstand).
 */

/** The share of the card's tighter side the framed piece takes. */
const val CARD_FILL = .78

/** The least share of the card's tighter side the boards alone take (a piece far from its wall). */
const val CARD_PIECE_MIN = .58

/** The least height the card shows at the aim, metres. */
const val CARD_MIN_VIEW = .75

/** Where a card's camera looks ([at]), how far from it it stands ([dist]) and the way from [at] to the eye ([back], unit). */
class CardFrame(val at: V3, val dist: Double, val back: V3) {
    val eye: V3 get() = at + back * dist
}

private fun crossV(a: V3, b: V3) = V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)

/** The camera's way to the eye from [az] round and [el] above level. */
fun cardBack(az: Double, el: Double) = V3(sin(az) * cos(el), sin(el), cos(az) * cos(el))

/**
 * Where [pts] fall in a picture of [aspect] (width / height) seen from [at] + [back] × [dist], [half] half the vertical
 * field of view: the lowest and highest x and y, each from -1 to 1 across the picture; null when one is behind the eye.
 */
fun cardSpan(pts: List<V3>, at: V3, dist: Double, back: V3, aspect: Double, half: Double): DoubleArray? {
    val f = back * -1.0; val r = crossV(f, V3(0.0, 1.0, 0.0)).unit(); val u = crossV(r, f)
    val tv = tan(half); val th = tv * aspect
    val o = doubleArrayOf(Double.MAX_VALUE, -Double.MAX_VALUE, Double.MAX_VALUE, -Double.MAX_VALUE)
    for (q in pts) {
        val v = q - at; val z = dist + v.dot(f)
        if (z < .05) return null
        val x = v.dot(r) / z / th; val y = v.dot(u) / z / tv
        o[0] = min(o[0], x); o[1] = max(o[1], x); o[2] = min(o[2], y); o[3] = max(o[3], y)
    }
    return o
}

/** The share of the picture's tighter side [pts] take ([cardSpan]); 99 when one is behind the eye. */
fun cardShare(pts: List<V3>, at: V3, dist: Double, back: V3, aspect: Double, half: Double): Double {
    val s = cardSpan(pts, at, dist, back, aspect, half) ?: return 99.0
    return max((s[1] - s[0]) / 2, (s[3] - s[2]) / 2)
}

/** How far off the camera stands for [pts] to take [share] of the picture ([cardShare] falls as it goes back). */
private fun distFor(pts: List<V3>, at: V3, back: V3, aspect: Double, half: Double, share: Double): Double {
    var lo = .05; var hi = 200.0
    for (i in 0 until 60) { val m = (lo + hi) / 2; if (cardShare(pts, at, m, back, aspect, half) > share) lo = m else hi = m }
    return hi
}

/** The aim moved across until [pts]' picture is centred, at [share] of the picture each time. */
private fun centred(pts: List<V3>, start: V3, back: V3, aspect: Double, half: Double, share: Double): V3 {
    val f = back * -1.0; val r = crossV(f, V3(0.0, 1.0, 0.0)).unit(); val u = crossV(r, f)
    val tv = tan(half); val th = tv * aspect
    var m = start
    for (i in 0 until 6) {
        val d = distFor(pts, m, back, aspect, half, share)
        val s = cardSpan(pts, m, d, back, aspect, half) ?: break
        m = m + r * ((s[0] + s[1]) / 2 * th * d) + u * ((s[2] + s[3]) / 2 * tv * d)
    }
    return m
}

/**
 * The card's camera ([cardFrame] rule above): [fit] what the card frames (PieceScene.cardExt), [piece] the boards'
 * bounds (PieceScene.ext), seen from [az] round and [el] above level, in a picture of [aspect] with [half] half the
 * vertical field of view.
 */
fun cardFrame(fit: List<V3>, piece: List<V3>, az: Double, el: Double, aspect: Double, half: Double): CardFrame {
    val back = cardBack(az, el)
    val pts = fit.ifEmpty { piece }
    if (pts.isEmpty()) return CardFrame(V3(0.0, .5, 0.0), 3.0, back)
    fun mid(ps: List<V3>) = V3((ps.minOf { it.x } + ps.maxOf { it.x }) / 2, (ps.minOf { it.y } + ps.maxOf { it.y }) / 2, (ps.minOf { it.z } + ps.maxOf { it.z }) / 2)
    var at = centred(pts, mid(pts), back, aspect, half, CARD_FILL)
    var d = distFor(pts, at, back, aspect, half, CARD_FILL)
    // the boards alone too small (a piece far from its wall): nearer, the boards centred
    if (piece.isNotEmpty() && cardShare(piece, at, d, back, aspect, half) < CARD_PIECE_MIN) {
        at = centred(piece, mid(piece), back, aspect, half, CARD_PIECE_MIN)
        d = distFor(piece, at, back, aspect, half, CARD_PIECE_MIN)
    }
    // a very small piece: not nearer than shows CARD_MIN_VIEW top to bottom
    d = max(d, CARD_MIN_VIEW / (2 * tan(half)))
    return CardFrame(at, d, back)
}
