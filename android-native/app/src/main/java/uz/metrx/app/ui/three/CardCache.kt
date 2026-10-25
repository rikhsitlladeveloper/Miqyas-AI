package uz.metrx.app.ui.three

import kotlinx.coroutines.CancellationException

/*
 * The gallery cards' pictures (modern 3D part 4, 25 Oct 2026): what a picture is made from, the memory cache and the
 * fall-back to the 2D painter. Pure Kotlin (CardCacheTest); the pictures themselves are made in Card3D.kt and kept by
 * ui/furniture/Cards.kt.
 */

/** Bumped whenever the card renderer draws differently: every card on disk is made again (2: the right way up on every driver, wardrobes in the modern 3D; 3: beds, tables and the rest). */
const val CARD_RENDER_VERSION = 4

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
