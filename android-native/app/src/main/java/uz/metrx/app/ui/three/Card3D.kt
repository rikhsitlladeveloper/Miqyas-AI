package uz.metrx.app.ui.three

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.filament.Camera
import com.google.android.filament.EntityManager
import com.google.android.filament.LightManager
import com.google.android.filament.Renderer
import com.google.android.filament.Scene
import com.google.android.filament.Skybox
import com.google.android.filament.SwapChain
import com.google.android.filament.SwapChainFlags
import com.google.android.filament.Texture
import com.google.android.filament.View
import com.google.android.filament.Viewport
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.node.Node
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.V3
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/*
 * The gallery cards drawn by the real 3D (modern 3D part 4, 25 Oct 2026): a piece's lit scene (the same ShellNodes,
 * materials, studio light and sun as the 3D screens, Scene3D.kt) rendered off screen by the app's one Filament engine
 * into a headless swap chain and read back into a Bitmap. Filament is driven from the thread that made the engine
 * (the main one): one card at a time, its few Filament calls on the main thread between frames, the rest (building
 * the scene, turning the pixels into a picture, saving it) off it. Any failure gives null: the caller draws the card
 * with the 2D painter instead (Cards.kt).
 */

private const val TAG = "Card3D"

/** The card's background: the mockup's studio grey (makeCards: clear colour #E4E8F0). */
const val CARD_BG = 0xE4E8F0

/** Where a card's camera stands and looks, and its vertical field of view in degrees. */
class CardCam(val eye: V3, val at: V3, val fovDeg: Double)

/** How long one card took: the whole job and the part on the main thread, ms (logged, and for the report). */
class CardTiming(val totalMs: Long, val mainMs: Long)

object Card3D {
    private val lock = Mutex()
    private var rig: Rig? = null
    private var broken = false
    @Volatile var last: CardTiming? = null; private set

    /** The off-screen renderer's parts, made once for the app's engine and kept (like the lit materials). */
    private class Rig(ctx: Context) {
        val engine = Engine3D.engine
        val renderer: Renderer = engine.createRenderer()
        val scene: Scene = engine.createScene()
        val view: View = engine.createView()
        val camEntity = EntityManager.get().create()
        val camera: Camera = engine.createCamera(camEntity)
        val ml = MaterialLoader(engine, ctx)
        val nodes = ShellNodes(engine, ml, ctx).apply { lit = true; grid = false }
        val root = Node(engine)
        val sky: Skybox = untonemapped(CARD_BG).let { c -> Skybox.Builder().color(c[0], c[1], c[2], 1f).build(engine) }
        val swaps = HashMap<Long, SwapChain>()
        val suns = HashMap<Tier, Int>()
        var sun = 0

        init {
            view.scene = scene; view.camera = camera
            scene.skybox = sky
            camera.setExposure(1f)
            renderer.clearOptions = Renderer.ClearOptions().apply { clear = true; clearColor = doubleArrayOf(.9, .91, .94, 1.0) }
        }

        fun swap(w: Int, h: Int): SwapChain = swaps.getOrPut((w.toLong() shl 32) or h.toLong()) { engine.createSwapChain(w, h, SwapChainFlags.CONFIG_READABLE) }

        /** The sun as on the 3D screens (warm white, soft shadows from a 1024 map), its shadows only on [tier]s that have them. */
        fun sunOf(tier: Tier): Int = suns.getOrPut(tier) {
            val e = EntityManager.get().create()
            LightManager.Builder(LightManager.Type.DIRECTIONAL).color(1f, .94f, .87f).intensity(SUN_LUX).direction(-.4f, -.8f, -.45f)
                .castShadows(tier.shadows)
                .shadowOptions(LightManager.ShadowOptions().apply { mapSize = 1024; shadowCascades = 1; constantBias = .001f; normalBias = 1f; shadowFar = 0f; stable = false })
                .build(engine, e)
            e
        }

        /** The view as Scene3D sets it for the lit furniture, in [tier]. */
        fun setUp(tier: Tier) {
            view.renderQuality = view.renderQuality.apply { hdrColorBuffer = View.QualityLevel.MEDIUM }
            view.colorGrading = Lit3D.grading(engine)
            view.ambientOcclusionOptions = view.ambientOcclusionOptions.apply {
                enabled = tier.ao; radius = .28f; intensity = .85f; power = 1.1f; quality = View.QualityLevel.LOW; resolution = .5f
            }
            view.bloomOptions = view.bloomOptions.apply { enabled = false }
            view.dynamicResolutionOptions = view.dynamicResolutionOptions.apply { enabled = false }
            view.multiSampleAntiAliasingOptions = view.multiSampleAntiAliasingOptions.apply { enabled = tier.msaa > 1; sampleCount = tier.msaa }
            view.antiAliasing = View.AntiAliasing.NONE
            // one frame: no temporal dithering to settle
            view.dithering = View.Dithering.NONE
            view.setShadowingEnabled(tier.shadows)
            view.setShadowType(View.ShadowType.PCF)
            view.isPostProcessingEnabled = true
            scene.indirectLight = Lit3D.ibl(engine, tier)
            val s = sunOf(tier)
            if (s != sun) { if (sun != 0) scene.removeEntity(sun); scene.addEntity(s); sun = s }
        }
    }

    /**
     * [shell] (a piece's lit scene) seen from [cam], [w] × [h] pixels in [tier]; null when the 3D cannot draw it (no lit
     * materials, no GL, a frame that never came back). One card at a time; suspends, never blocks the caller's thread.
     */
    suspend fun render(ctx: Context, shell: Shell3D, cam: CardCam, w: Int, h: Int, tier: Tier): Bitmap? = lock.withLock {
        if (broken) return@withLock null
        val t0 = System.nanoTime()
        var main = 0L
        val px = withContext(Dispatchers.Main.immediate) {
            runCatching { draw(ctx.applicationContext, shell, cam, w, h, tier) { main += it } }
                .onFailure { Log.w(TAG, "card render failed", it); if (it is LinkageError) broken = true }
                .getOrNull()
        } ?: return@withLock null
        val bmp = withContext(Dispatchers.Default) { runCatching { toBitmap(px, w, h) }.getOrNull() }
        val t = CardTiming((System.nanoTime() - t0) / 1_000_000, main / 1_000_000)
        last = t
        Log.i(TAG, "card ${w}x$h $tier: ${t.totalMs} ms, ${t.mainMs} ms on the main thread, ${shell.parts.size} parts")
        bmp
    }

    /**
     * On the main thread: builds the scene, renders one frame and reads it back. [spent] adds up the main thread's
     * time between the waits (the waits themselves let the app run on).
     */
    private suspend fun draw(ctx: Context, shell: Shell3D, cam: CardCam, w: Int, h: Int, tier: Tier, spent: (Long) -> Unit): ByteBuffer? {
        fun <T> timed(f: () -> T): T { val t = System.nanoTime(); try { return f() } finally { spent(System.nanoTime() - t) } }
        val engine = Engine3D.engine
        if (!Lit3D.ready(engine, ctx)) { broken = true; return null }
        val buf = ByteBuffer.allocateDirect(w * h * 4).order(ByteOrder.nativeOrder())
        var done = false
        val (r, sc, ents) = timed {
            val r = rig ?: Rig(ctx).also { rig = it }
            r.nodes.tier = tier
            r.setUp(tier)
            // the sun from behind the viewer, a little to the right and high, as on the 3D screens
            val th = atan2(cam.eye.z - cam.at.z, cam.eye.x - cam.at.x) + .5
            val d = V3(-cos(th), -1.35, -sin(th)).unit()
            engine.lightManager.setDirection(engine.lightManager.getInstance(r.sun), d.x.toFloat(), d.y.toFloat(), d.z.toFloat())
            r.camera.setProjection(cam.fovDeg, w.toDouble() / h, .05, 80.0, Camera.Fov.VERTICAL)
            r.camera.lookAt(cam.eye.x, cam.eye.y, cam.eye.z, cam.at.x, cam.at.y, cam.at.z, 0.0, 1.0, 0.0)
            r.view.viewport = Viewport(0, 0, w, h)
            val sc = r.swap(w, h)
            r.nodes.build(r.root, shell)
            val ents = r.root.childNodes.map { it.entity }
            ents.forEach { r.scene.addEntity(it) }
            Triple(r, sc, ents)
        }
        try {
            // a frame may be refused while the GPU is busy (a 3D screen drawing too): tried again a little later
            var began = false
            for (i in 0 until 40) {
                if (timed { r.renderer.beginFrame(sc, System.nanoTime()) }) { began = true; break }
                delay(16)
            }
            if (!began) { Log.w(TAG, "no frame"); return null }
            timed {
                r.renderer.render(r.view)
                r.renderer.readPixels(0, 0, w, h, Texture.PixelBufferDescriptor(buf, Texture.Format.RGBA, Texture.Type.UBYTE, 1, 0, 0, w,
                    Handler(Looper.getMainLooper()), Runnable { done = true }))
                r.renderer.endFrame()
            }
            // the pixels come back once the GPU is done: waited for without holding the main thread
            for (i in 0 until 90) { if (done) break; delay(8) }
            if (!done) { timed { engine.flushAndWait() }; for (i in 0 until 30) { if (done) break; delay(10) } }
            if (!done) Log.w(TAG, "the pixels never came back")
            return if (done) buf else null
        } finally {
            // the scene goes, its buffers with it (after the GPU is done with them)
            timed {
                ents.forEach { r.scene.removeEntity(it) }
                if (!done) engine.flushAndWait()
                r.nodes.clear(r.root)
            }
        }
    }

    /** Filament's rows run from the bottom up: turned over into a picture. */
    private fun toBitmap(px: ByteBuffer, w: Int, h: Int): Bitmap {
        val row = w * 4
        val out = ByteBuffer.allocateDirect(row * h)
        val line = ByteArray(row)
        for (y in 0 until h) { px.position((h - 1 - y) * row); px.get(line); out.put(line) }
        out.rewind()
        return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { copyPixelsFromBuffer(out); setHasAlpha(false) }
    }
}
