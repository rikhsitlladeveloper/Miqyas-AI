package uz.metrx.app.ui.furniture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.yield
import kotlinx.serialization.json.Json
import uz.metrx.app.furniture.FModelDef
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.withPreset
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.three.CARD_BG
import uz.metrx.app.ui.three.Card3D
import uz.metrx.app.ui.three.CardFallback
import uz.metrx.app.ui.three.CardKey
import uz.metrx.app.ui.three.Lru
import uz.metrx.app.ui.three.Quality3D
import uz.metrx.app.ui.three.Tier
import uz.metrx.app.ui.three.cardSize
import uz.metrx.app.ui.three.digest
import uz.metrx.app.ui.three.pieceDigest
import java.io.File

/*
 * The gallery's cards (modern 3D part 4, 25 Oct 2026): each model at its usual size in the order's design style, drawn
 * once by the real 3D (Card3D.kt) and kept: in memory (the most recent ones) and on disk as WebP in cacheDir/cards/, by
 * a key of everything the picture depends on (CardCache.kt). One card is made at a time, the ones on screen first; while
 * it is being made the card shimmers. If the 3D cannot draw it, the 2D painter does (PieceView.kt), so a card always shows.
 */

private const val TAG = "Cards"

/** A model's lit scene as the 3D screens build a piece without a room, with the walls it stands against behind it. */
internal fun cardShell(f: Furniture, ws: Workshop, mats: List<Mat>, light: Boolean = false): Shell3D {
    val room = freeRoom(f)
    val b = buildShell(listOf(room), true, true)
    val fur = furniture3D(listOf(f), b.bases, ws, matRgb(mats), emptySet(), look = matLook(mats), mats = mats, light = light)
    val on = f.walls.filter { it != ISLAND }.toSet()
    val keep = b.parts.filter { it.role == Role.FLOOR || (it.role == Role.WALL && it.wall in on) }
    return Shell3D(keep, emptyList(), b.groups, emptyList(), null, b.L, b.W, b.H, b.tgt, b.r, b.theta, b.phi, b.bounds, b.rMin, b.fit,
        b.gridSize, b.gridDiv, b.gridCx, b.gridCz, b.light, b.far, b.bases).plus(fur.parts, fur.edges)
}

/** A gallery model's piece: its usual size, in the order's design [style] as a new piece gets it (App.addPiece). */
internal fun galleryPiece(m: FModelDef, ws: Workshop, style: String): Furniture {
    val f = pieceOf(m, emptyMap(), ws, "")
    return if (style.isNotEmpty()) withPreset(f, style, fresh = true, ws = ws) else f
}

/** The workshop's materials and settings as the cards see them (their colours, decors, finishes, thicknesses). */
internal fun matsLine(mats: List<Mat>, ws: Workshop): String =
    mats.joinToString(";") { "${it.id},${it.kind},${it.rgb},${it.tex},${it.finish},${it.t}" } + "#" + ws.toString()

private val JSON = Json { encodeDefaults = false }

object Cards {
    private val mem = Lru<String, ImageBitmap>(minOf(48L shl 20, Runtime.getRuntime().maxMemory() / 8)) { it.width.toLong() * it.height * 4 }
    private val fallback = CardFallback()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    /** A card waiting to be made; the ones on screen ([shown]) go first. Touched on the main thread only, like [queue]. */
    private class Req(val key: CardKey, val inp: String, val f: Furniture, val ws: Workshop, val mats: List<Mat>, val tier: Tier, val ctx: Context) {
        var started = false
        val waiters = ArrayList<CompletableDeferred<ImageBitmap?>>()
    }
    private val queue = LinkedHashMap<String, Req>()
    private var worker: Job? = null
    /** The key each model's card had for the inputs it was asked with (so a card in memory shows without waiting). */
    private val keys = HashMap<String, CardKey>()
    /** The cards on screen, by their inputs (told by the cards as they move, before their keys are known). */
    private val shown = HashSet<String>()
    private var pruned = false

    /** What a model's card is asked with, in one line (this run only: hash codes). */
    fun inputs(m: FModelDef, style: String, ws: Workshop, mats: List<Mat>, tier: Tier) = "${m.id}|$style|${ws.hashCode()}|${mats.hashCode()}|$tier"

    /** The card already in memory, if any (no waiting, for the first frame). */
    fun peek(inp: String): ImageBitmap? = keys[inp]?.let { k -> mem[k.id] }

    /** Whether the card asked with [inp] is on screen: those are made first. */
    fun seen(inp: String, on: Boolean) { if (on) shown += inp else shown -= inp }

    /** Model [m]'s card: from memory, from disk, or made (waits its turn). Called on the main thread. */
    suspend fun model(ctx: Context, m: FModelDef, style: String, ws: Workshop, mats: List<Mat>, tier: Tier): ImageBitmap? {
        val inp = inputs(m, style, ws, mats, tier)
        val (key, f) = withContext(Dispatchers.Default) {
            val f = galleryPiece(m, ws, style)
            CardKey(m.id, "", style, digest(matsLine(mats, ws)), f.handle, tier.name, pieceDigest(JSON.encodeToString(Furniture.serializer(), f))) to f
        }
        keys[inp] = key
        mem[key.id]?.let { return it }
        val file = File(dir(ctx), key.file)
        withContext(Dispatchers.IO) {
            pruneOnce(ctx)
            if (file.exists()) runCatching { BitmapFactory.decodeFile(file.path)?.asImageBitmap() }.getOrNull() else null
        }?.let { mem.put(key.id, it); return it }
        val req = queue[key.id] ?: Req(key, inp, f, ws, mats, tier, ctx.applicationContext).also { queue[key.id] = it; kick() }
        val d = CompletableDeferred<ImageBitmap?>()
        req.waiters += d
        try {
            return d.await()
        } finally {
            // the card left the screen before its turn: it is not made
            if (!d.isCompleted) { req.waiters -= d; if (req.waiters.isEmpty() && !req.started) queue.remove(key.id) }
        }
    }

    /** One card at a time, the visible ones first. */
    private fun kick() {
        if (worker?.isActive == true) return
        worker = scope.launch {
            while (true) {
                val r = queue.values.firstOrNull { it.inp in shown } ?: queue.values.firstOrNull() ?: break
                r.started = true
                val img = runCatching { make(r) }.onFailure { Log.w(TAG, "card ${r.key.model}", it) }.getOrNull()
                queue.remove(r.key.id)
                if (img != null) mem.put(r.key.id, img)
                r.waiters.forEach { it.complete(img) }
                yield()
            }
        }
    }

    /** The real 3D's picture (kept on disk), or the 2D painter's when the 3D gives none. */
    private suspend fun make(r: Req): ImageBitmap? {
        val (w, h) = cardSize(r.tier)
        val (shell, scene) = withContext(Dispatchers.Default) { cardShell(r.f, r.ws, r.mats, r.tier == uz.metrx.app.ui.three.Tier.LOW) to pieceScene(r.f, r.ws, r.mats) }
        val file = File(dir(r.ctx), r.key.file)
        return fallback.pick(
            real = {
                Card3D.render(r.ctx, shell, cardCamOf(scene, w, h), w, h, r.tier)?.let { bmp ->
                    withContext(Dispatchers.IO) { save(file, bmp) }
                    bmp.asImageBitmap()
                }
            },
            paint = { withContext(Dispatchers.Default) { piecePicture(scene, w, h, 2f) } }
        )?.also { (_, real) -> if (!real) Log.i(TAG, "card ${r.key.model} drawn by the 2D painter") }?.first
    }

    private fun dir(ctx: Context) = File(ctx.cacheDir, "cards")

    /** Written to a file beside it first, so a half-written picture is never read. */
    private fun save(file: File, bmp: Bitmap) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.path + ".tmp")
            @Suppress("DEPRECATION")
            val fmt = if (android.os.Build.VERSION.SDK_INT >= 30) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
            tmp.outputStream().use { bmp.compress(fmt, 90, it) }
            if (!tmp.renameTo(file)) { file.delete(); tmp.renameTo(file) }
        }.onFailure { Log.w(TAG, "card not saved", it) }
    }

    /** Once a run: past 400 pictures (old styles, old materials), the oldest go down to 300. */
    private fun pruneOnce(ctx: Context) {
        if (pruned) return
        pruned = true
        runCatching {
            val fs = dir(ctx).listFiles()?.filter { it.isFile } ?: return
            fs.filter { it.name.endsWith(".tmp") }.forEach { it.delete() }
            val pics = fs.filter { it.name.endsWith(".webp") }
            if (pics.size > 400) pics.sortedBy { it.lastModified() }.take(pics.size - 300).forEach { it.delete() }
        }
    }
}

/** A gallery card's picture: model [m] drawn by the real 3D in the order's [style], a shimmer until it is ready. */
@Composable
internal fun ModelPic(m: FModelDef, style: String, modifier: Modifier) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val ws = app.settings.workshop; val mats = app.settings.mats
    val q = app.settings.quality
    val tier = remember(q) { Quality3D.tier(ctx, q) }
    val inp = remember(m.id, style, ws, mats, tier) { Cards.inputs(m, style, ws, mats, tier) }
    // the state outlives its key: another style (UX upgrades §7, the gallery's style row) keeps the old picture only
    // until the new one is made, so the cards repaint
    val img by produceState(Cards.peek(inp), inp) {
        Cards.peek(inp)?.let { value = it; return@produceState }
        value = Cards.model(ctx, m, style, ws, mats, tier) ?: value
    }
    androidx.compose.runtime.DisposableEffect(inp) { onDispose { Cards.seen(inp, false) } }
    Box(modifier.onGloballyPositioned { c -> Cards.seen(inp, !c.boundsInWindow().isEmpty) }) {
        val i = img
        if (i != null) Image(i, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) else Shimmer(Modifier.fillMaxSize())
    }
}

private val SH_BASE = Color(0xFF000000.toInt() or CARD_BG)
private val SH_HI = Color(0xFFF4F6FA)

/** A soft light sweeping across while a card's picture is made. */
@Composable
internal fun Shimmer(modifier: Modifier) {
    val t = rememberInfiniteTransition("shimmer")
    val x by t.animateFloat(-.6f, 1.6f, infiniteRepeatable(tween(1200, easing = LinearEasing)), "x")
    Box(modifier.drawBehind {
        drawRect(SH_BASE)
        val w = size.width
        drawRect(Brush.linearGradient(listOf(SH_BASE, SH_HI, SH_BASE), start = Offset(w * x - w * .4f, 0f), end = Offset(w * x + w * .4f, size.height)))
    })
}
