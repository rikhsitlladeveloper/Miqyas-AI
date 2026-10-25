package uz.metrx.app.ui.three

import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.EGL14
import android.opengl.GLES20
import android.util.Log
import com.google.android.filament.ColorGrading
import com.google.android.filament.Colors
import com.google.android.filament.Engine
import com.google.android.filament.IndirectLight
import com.google.android.filament.Material
import com.google.android.filament.MaterialInstance
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.ToneMapper
import com.google.android.filament.android.TextureHelper
import uz.metrx.app.geo.Look
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/*
 * The lit 3D of furniture (modern 3D part 1): Filament's lit materials, the CC0 decor pictures, a small studio
 * light (image-based, made here) and a sun with soft shadows, in two quality tiers. Everything here is made once
 * for the app's one engine and kept: a 3D screen only picks from it. If the lit materials cannot be loaded the
 * furniture is drawn as before, in flat baked colours (Scene3D).
 */

private const val TAG = "Render3D"

/** How much the 3D does: everything on strong phones, no shadows or sharp reflections and small pictures on weak ones. */
enum class Tier(
    val texSize: Int, val shadows: Boolean, val reflections: Boolean, val msaa: Int, val ao: Boolean,
    /** The picture is drawn at this share of the screen's pixels and stretched (weak phones with dense screens). */
    val maxScale: Float
) {
    HIGH(512, true, true, 4, true, 1f),
    LOW(256, false, false, 2, false, .8f)
}

/** Which tier a phone gets (Profile → Sifat: "auto", "high", "low"). */
object Quality3D {
    /** The GPU's name (GL_RENDERER), read once before the 3D engine starts. */
    @Volatile var gpu: String? = null; private set
    private var autoTier: Tier? = null
    /** Why "auto" chose what it chose, for the log and the tests. */
    var reasons: List<String> = emptyList(); private set

    fun tier(ctx: Context, setting: String): Tier = when (setting) {
        "high" -> Tier.HIGH
        "low" -> Tier.LOW
        else -> auto(ctx)
    }

    fun auto(ctx: Context): Tier {
        autoTier?.let { return it }
        if (gpu == null) readGpu()
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val mi = ActivityManager.MemoryInfo().also { am?.getMemoryInfo(it) }
        val r = weakReasons(android.os.Build.VERSION.SDK_INT, am?.isLowRamDevice == true, mi.totalMem, gpu)
        reasons = r
        val t = if (r.isEmpty()) Tier.HIGH else Tier.LOW
        Log.i(TAG, "auto quality $t (gpu=$gpu, ram=${mi.totalMem / 1_000_000} MB, sdk=${android.os.Build.VERSION.SDK_INT}, ${r.joinToString()})")
        autoTier = t
        return t
    }

    /**
     * What makes a phone weak for the lit 3D: Android 9 or older (the founder's Mi 6X, Android 8.1), a low-RAM device,
     * under 4 GB of memory (a "4 GB" phone reports a little less), or an old GPU.
     */
    fun weakReasons(sdk: Int, lowRam: Boolean, totalMem: Long, gpu: String?): List<String> {
        val out = ArrayList<String>()
        if (sdk < 29) out += "sdk<29"
        if (lowRam) out += "lowRam"
        if (totalMem in 1 until 3_800_000_000L) out += "ram<4GB"
        if (gpu != null && weakGpu(gpu)) out += "gpu"
        return out
    }

    /** Adreno 5xx and older and the low 6xx; Mali-T, -4xx and the small G3x/G5x; PowerVR GE; software renderers. */
    fun weakGpu(r: String): Boolean {
        val s = r.lowercase()
        if ("swiftshader" in s || "llvmpipe" in s || "softpipe" in s) return true
        Regex("adreno[^0-9]*([0-9]{3})").find(s)?.let { m -> val n = m.groupValues[1].toInt(); return n < 600 || n in 600..612 }
        if ("mali-t" in s || Regex("mali-4[0-9]{2}").containsMatchIn(s)) return true
        // Mali-G31, G51, G52 (budget phones) and the first Bifrost G71, G72 (2017)
        Regex("mali-g([0-9]{2})").find(s)?.let { m -> val n = m.groupValues[1].toInt(); return n in 31..52 || n in 71..72 }
        if ("powervr" in s && ("ge8" in s || "rogue g" in s || "sgx" in s)) return true
        return false
    }

    /** GL_RENDERER from a throwaway EGL context (the engine's own is made after). */
    fun readGpu() {
        runCatching {
            val prevDpy = EGL14.eglGetCurrentDisplay(); val prevCtx = EGL14.eglGetCurrentContext()
            val prevDraw = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW); val prevRead = EGL14.eglGetCurrentSurface(EGL14.EGL_READ)
            val dpy = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            val v = IntArray(2); EGL14.eglInitialize(dpy, v, 0, v, 1)
            val cfgs = arrayOfNulls<android.opengl.EGLConfig>(1); val n = IntArray(1)
            EGL14.eglChooseConfig(dpy, intArrayOf(EGL14.EGL_RENDERABLE_TYPE, 4, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE), 0, cfgs, 0, 1, n, 0)
            val cfg = cfgs[0] ?: return
            val ctx = EGL14.eglCreateContext(dpy, cfg, EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
            val surf = EGL14.eglCreatePbufferSurface(dpy, cfg, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
            if (EGL14.eglMakeCurrent(dpy, surf, surf, ctx)) gpu = GLES20.glGetString(GLES20.GL_RENDERER)
            if (prevCtx != EGL14.EGL_NO_CONTEXT) EGL14.eglMakeCurrent(prevDpy, prevDraw, prevRead, prevCtx)
            else EGL14.eglMakeCurrent(dpy, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(dpy, surf); EGL14.eglDestroyContext(dpy, ctx)
        }.onFailure { Log.w(TAG, "no GPU name", it) }
    }
}

/* ---------------- colour ---------------- */

internal fun srgbToLinear(c: Float): Float = if (c <= .04045f) c / 12.92f else ((c + .055f) / 1.055f).pow(2.4f)

/** The Khronos PBR Neutral tone mapper (Filament's PBRNeutralToneMapper), on linear RGB. */
internal fun pbrNeutral(c: FloatArray): FloatArray {
    val start = .8f - .04f; val desat = .15f
    var r = c[0]; var g = c[1]; var b = c[2]
    val x = min(r, min(g, b)); val off = if (x < .08f) x - 6.25f * x * x else .04f
    r -= off; g -= off; b -= off
    val peak = max(r, max(g, b))
    if (peak < start) return floatArrayOf(r, g, b)
    val d = 1f - start; val np = 1f - d * d / (peak + d - start)
    val k = np / peak; r *= k; g *= k; b *= k
    val gg = 1f - 1f / (desat * (peak - np) + 1f)
    return floatArrayOf(r + (np - r) * gg, g + (np - g) * gg, b + (np - b) * gg)
}

/** The linear colour that comes out of the tone mapper as sRGB [rgb]: flat things (the background) keep their colour. */
fun untonemapped(rgb: Int): FloatArray {
    val t = floatArrayOf(srgbToLinear(((rgb shr 16) and 255) / 255f), srgbToLinear(((rgb shr 8) and 255) / 255f), srgbToLinear((rgb and 255) / 255f))
    val v = t.copyOf()
    repeat(80) {
        val f = pbrNeutral(v)
        for (i in 0..2) {
            // the slope of this channel alone, numerically: the tone curve flattens near white, so steps grow there
            val h = 1e-3f; val v2 = v.copyOf(); v2[i] += h
            val s = max(.05f, (pbrNeutral(v2)[i] - f[i]) / h)
            v[i] = max(0f, v[i] + (t[i] - f[i]) / s * .8f)
        }
    }
    return v
}

/* ---------------- the lit materials, the pictures, the light ---------------- */

object Lit3D {
    private var tried = false
    private var opaque: Material? = null
    private var textured: Material? = null
    private var clear: Material? = null
    /** The lit materials loaded: the furniture is drawn lit (false: flat colours, as before). */
    var ok = false; private set
    private val insts = HashMap<Any, MaterialInstance>()
    private val texs = HashMap<String, Texture?>()
    private val ibls = HashMap<Tier, IndirectLight>()
    private var grading: ColorGrading? = null
    private var sampler: TextureSampler? = null

    /** Loads SceneView's lit materials once (a failure is remembered: flat colours from then on). */
    fun ready(engine: Engine, ctx: Context): Boolean {
        if (tried) return ok
        tried = true
        runCatching {
            fun load(name: String): Material {
                val bytes = ctx.assets.open("materials/$name.filamat").use { it.readBytes() }
                val buf = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).put(bytes).also { it.flip() }
                return Material.Builder().payload(buf, buf.remaining()).build(engine)
            }
            opaque = load("opaque_colored"); textured = load("opaque_textured"); clear = load("transparent_colored")
            ok = true
        }.onFailure { Log.w(TAG, "lit materials failed, flat colours", it); ok = false }
        return ok
    }

    /** The tone curve: neutral (base colours stay as picked), a touch warm from the light itself. */
    fun grading(engine: Engine): ColorGrading = grading ?: ColorGrading.Builder()
        .toneMapper(ToneMapper.PBRNeutralToneMapper())
        .build(engine).also { grading = it }

    /** The material of [look] on tier [tier] ([alpha] the see-through of a wall turned away; 1 solid). */
    fun instance(engine: Engine, ctx: Context, look: Look, tier: Tier, alpha: Float = look.alpha): MaterialInstance? {
        val l = if (tier == Tier.LOW) look.light() else look
        val key = Triple(l, tier, (alpha * 100).toInt())
        insts[key]?.let { return it }
        val mi = runCatching { make(engine, ctx, l, tier, alpha) }.onFailure { Log.w(TAG, "material $l", it) }.getOrNull() ?: return null
        insts[key] = mi
        return mi
    }

    private fun make(engine: Engine, ctx: Context, l: Look, tier: Tier, alpha: Float): MaterialInstance? {
        val r = ((l.rgb shr 16) and 255) / 255f; val g = ((l.rgb shr 8) and 255) / 255f; val b = (l.rgb and 255) / 255f
        // a lacquer coat is drawn as a sharper, stronger highlight (SceneView's materials have no clear coat)
        val rough = if (l.clear > 0f) min(l.rough, .12f) else l.rough
        val refl = if (l.clear > 0f) max(l.reflect, .5f + .45f * l.clear) else l.reflect
        val tex = l.tex?.let { texture(engine, ctx, it, tier, if (l.tint) l.rgb else null) }
        val mi = when {
            alpha < .999f -> clear?.createInstance()?.apply {
                // the colour goes in already multiplied by its opacity (Filament's transparent blending)
                setParameter("color", Colors.RgbaType.PREMULTIPLIED_LINEAR, srgbToLinear(r) * alpha, srgbToLinear(g) * alpha, srgbToLinear(b) * alpha, alpha)
                setDepthWrite(false)
            }
            tex != null -> textured?.createInstance()?.apply { setParameter("texture", tex, sampler(tier)) }
            else -> opaque?.createInstance()?.apply { setParameter("color", Colors.RgbaType.SRGB, r, g, b, 1f) }
        } ?: return null
        mi.setParameter("metallic", l.metal); mi.setParameter("roughness", rough); mi.setParameter("reflectance", refl)
        // the shadow map takes the boxes' back faces: their fronts do not shadow themselves in stripes (acne)
        mi.setCullingMode(Material.CullingMode.BACK, Material.CullingMode.FRONT)
        return mi
    }

    private fun sampler(tier: Tier): TextureSampler = sampler ?: TextureSampler(TextureSampler.MinFilter.LINEAR_MIPMAP_LINEAR, TextureSampler.MagFilter.LINEAR, TextureSampler.WrapMode.REPEAT)
        .apply { anisotropy = if (tier == Tier.HIGH) 4f else 2f }.also { sampler = it }

    /** Picture [id] at the tier's size from assets/tex/, mipmapped; [tint] (sRGB) multiplies a grey picture (fabrics). */
    fun texture(engine: Engine, ctx: Context, id: String, tier: Tier, tint: Int?): Texture? {
        val key = "$id@${tier.texSize}#${tint ?: -1}"
        if (key in texs) return texs[key]
        val t = runCatching {
            // a decor's id names a bundled picture, recoloured for its shade (geo/Look.kt TEXTURES)
            val info = uz.metrx.app.geo.TEXTURES[id]
            val file = info?.file?.takeIf { it.isNotEmpty() } ?: id
            val bmp = ctx.assets.open("tex/${tier.texSize}/$file.webp").use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }) }
                ?: error("no picture $id")
            val recol = info?.tint?.let { to -> uz.metrx.app.geo.TEXTURES[file]?.avg?.let { from -> recoloured(bmp, from, to) } } ?: bmp
            val src = if (tint != null) tinted(recol, tint) else recol
            val levels = 1 + (31 - Integer.numberOfLeadingZeros(max(src.width, src.height)))
            Texture.Builder().width(src.width).height(src.height).levels(levels).sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.SRGB8_A8).usage(Texture.Usage.DEFAULT or Texture.Usage.GEN_MIPMAPPABLE).build(engine).also { tx ->
                    TextureHelper.setBitmap(engine, tx, 0, src)
                    tx.generateMipmaps(engine)
                }
        }.onFailure { Log.w(TAG, "texture $id", it) }.getOrNull()
        texs[key] = t
        return t
    }

    /** A coloured picture whose average is [from] moved to average [to] (each channel scaled in linear light). */
    private fun recoloured(bmp: Bitmap, from: Int, to: Int): Bitmap {
        val w = bmp.width; val h = bmp.height; val px = IntArray(w * h); bmp.getPixels(px, 0, w, 0, 0, w, h)
        val lin = FloatArray(256) { srgbToLinear(it / 255f) }
        val enc = IntArray(4096) { i -> val v = i / 4095f; ((if (v <= .0031308f) v * 12.92f else 1.055f * v.pow(1 / 2.4f) - .055f) * 255f + .5f).toInt().coerceIn(0, 255) }
        fun k(sh: Int) = lin[(to shr sh) and 255] / max(1e-4f, lin[(from shr sh) and 255])
        val kr = k(16); val kg = k(8); val kb = k(0)
        fun ch(c: Int, f: Float) = enc[(lin[c] * f * 4095f).toInt().coerceIn(0, 4095)]
        for (i in px.indices) { val c = px[i]; px[i] = (0xFF shl 24) or (ch((c shr 16) and 255, kr) shl 16) or (ch((c shr 8) and 255, kg) shl 8) or ch(c and 255, kb) }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    /** A grey picture times colour [tint], in linear light. */
    private fun tinted(bmp: Bitmap, tint: Int): Bitmap {
        val w = bmp.width; val h = bmp.height; val px = IntArray(w * h); bmp.getPixels(px, 0, w, 0, 0, w, h)
        val lin = FloatArray(256) { srgbToLinear(it / 255f) }
        val enc = IntArray(4096) { i -> val v = i / 4095f; ((if (v <= .0031308f) v * 12.92f else 1.055f * v.pow(1 / 2.4f) - .055f) * 255f + .5f).toInt().coerceIn(0, 255) }
        val tr = lin[(tint shr 16) and 255] / lin[0xD5]; val tg = lin[(tint shr 8) and 255] / lin[0xD5]; val tb = lin[tint and 255] / lin[0xD5]
        fun ch(c: Int, k: Float) = enc[(lin[c] * k * 4095f).toInt().coerceIn(0, 4095)]
        for (i in px.indices) { val c = px[i]; px[i] = (0xFF shl 24) or (ch((c shr 16) and 255, tr) shl 16) or (ch((c shr 8) and 255, tg) shl 8) or ch(c and 255, tb) }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    /**
     * The studio's light for tier [tier]: its spherical harmonics (soft light from all round) and, on strong phones,
     * a small prefiltered cubemap for reflections in gloss, glass and metal.
     */
    fun ibl(engine: Engine, tier: Tier): IndirectLight = ibls.getOrPut(tier) {
        val t0 = System.nanoTime()
        val b = IndirectLight.Builder().irradiance(3, Studio.sh()).intensity(Studio.INTENSITY)
        if (tier.reflections) runCatching { b.reflections(Studio.cubemap(engine, 64)) }.onFailure { Log.w(TAG, "no reflections", it) }
        b.build(engine).also { Log.i(TAG, "studio light $tier in ${(System.nanoTime() - t0) / 1_000_000} ms") }
    }
}

/**
 * The studio round the furniture, as in the mockup's makeEnv: light walls, a ceiling with three light strips, a dark
 * warm floor, a large bright window behind the viewer and two smaller ones at the sides. Linear light, 1 = white paper.
 */
internal object Studio {
    // a touch brighter in part 3 (was .62), the fronts nearer the mockup's
    const val INTENSITY = .72f

    private fun lin(rgb: Int) = floatArrayOf(srgbToLinear(((rgb shr 16) and 255) / 255f), srgbToLinear(((rgb shr 8) and 255) / 255f), srgbToLinear((rgb and 255) / 255f))
    // the floor a light warm grey (mockup #4A382A, but its gloss reflected the real plank floor; part 3: no longer the
    // orange of wood, which turned graphite and white gloss fronts brown): gloss, mirrors and steel seen from above
    // mostly show it
    private val SIDE = lin(0xB3ADA4); private val END = lin(0xBDB8B0); private val CEIL = lin(0xF4F1EC); private val FLOOR = lin(0x9A948C)

    /** The light coming from direction ([x], [y], [z]) (unit), seen from the studio's middle. */
    fun radiance(x: Float, y: Float, z: Float): FloatArray {
        // a box 14 × 7 × 14 m round the eye, its floor 2 m below
        val tx = if (x > 0) 7f / x else if (x < 0) -7f / x else Float.MAX_VALUE
        val ty = if (y > 0) 5f / y else if (y < 0) -2f / y else Float.MAX_VALUE
        val tz = if (z > 0) 7f / z else if (z < 0) -7f / z else Float.MAX_VALUE
        val t = min(tx, min(ty, tz)); val px = x * t; val py = y * t; val pz = z * t
        fun lamp(i: Float, warm: Float = 1f) = floatArrayOf(i, i * .98f, i * .94f * warm)
        return when (t) {
            ty -> if (y > 0) {
                if (abs(px) < 2.5f && listOf(-3f, 0f, 3f).any { abs(pz - it) < .2f }) lamp(6f) else CEIL
            } else {
                // the floor lighter towards the walls (lit from the windows): a mirror shows a soft gradient, not a flat panel
                val k = .6f + .9f * min(1f, sqrt(px * px + pz * pz) / 7f)
                floatArrayOf(FLOOR[0] * k, FLOOR[1] * k, FLOOR[2] * k)
            }
            tz -> if (z > 0 && abs(px - 1.2f) < 2.1f && abs(py - .9f) < 1.2f) lamp(7f) else END
            else -> when {
                x < 0 && abs(pz + 1.5f) < 1.3f && abs(py - .9f) < 1.2f -> lamp(5f)
                x > 0 && abs(pz + 2f) < 1.3f && abs(py - .9f) < 1.2f -> lamp(4f)
                else -> SIDE
            }
        }
    }

    /** The light's 9 spherical-harmonics numbers as Filament wants them (cosine-convolved, over π, basis-scaled). */
    fun sh(): FloatArray {
        val out = DoubleArray(27)
        val nT = 96; val nP = 192
        for (i in 0 until nT) {
            val th = PI * (i + .5) / nT; val st = sin(th); val ct = cos(th)
            val dw = (PI / nT) * (2 * PI / nP) * st
            for (j in 0 until nP) {
                val ph = 2 * PI * (j + .5) / nP
                val x = st * cos(ph); val z = st * sin(ph); val y = ct
                val l = radiance(x.toFloat(), y.toFloat(), z.toFloat())
                val p = doubleArrayOf(1.0, y, z, x, y * x, y * z, 3 * z * z - 1, z * x, x * x - y * y)
                for (k in 0..8) for (c in 0..2) out[k * 3 + c] += l[c] * p[k] * dw
            }
        }
        // A_l (π, 2π/3, π/4) × K_lm² / π
        val a = doubleArrayOf(PI, 2 * PI / 3, 2 * PI / 3, 2 * PI / 3, PI / 4, PI / 4, PI / 4, PI / 4, PI / 4)
        val k2 = doubleArrayOf(1 / (4 * PI), 3 / (4 * PI), 3 / (4 * PI), 3 / (4 * PI), 15 / (4 * PI), 15 / (4 * PI), 5 / (16 * PI), 15 / (4 * PI), 15 / (16 * PI))
        return FloatArray(27) { (out[it] * a[it / 3] * k2[it / 3] / PI).toFloat() }
    }

    /** The studio as a cubemap [n] px a side, prefiltered for every roughness (Filament's own filter). */
    fun cubemap(engine: Engine, n: Int): Texture {
        val levels = 1 + (31 - Integer.numberOfLeadingZeros(n))
        val tex = Texture.Builder().width(n).height(n).levels(levels).sampler(Texture.Sampler.SAMPLER_CUBEMAP)
            .format(Texture.InternalFormat.R11F_G11F_B10F).build(engine)
        val face = n * n * 3 * 4
        val buf = ByteBuffer.allocateDirect(face * 6).order(ByteOrder.nativeOrder())
        val fb = buf.asFloatBuffer()
        for (f in 0 until 6) for (row in 0 until n) for (col in 0 until n) {
            val s = 2f * (col + .5f) / n - 1f; val t = 2f * (row + .5f) / n - 1f
            // the GL cubemap faces: +x, -x, +y, -y, +z, -z
            var dx: Float; var dy: Float; var dz: Float
            when (f) { 0 -> { dx = 1f; dy = -t; dz = -s }; 1 -> { dx = -1f; dy = -t; dz = s }; 2 -> { dx = s; dy = 1f; dz = t }
                3 -> { dx = s; dy = -1f; dz = -t }; 4 -> { dx = s; dy = -t; dz = 1f }; else -> { dx = -s; dy = -t; dz = -1f } }
            val l = sqrt(dx * dx + dy * dy + dz * dz); val c = radiance(dx / l, dy / l, dz / l)
            fb.put(c[0]); fb.put(c[1]); fb.put(c[2])
        }
        val pbd = Texture.PixelBufferDescriptor(buf, Texture.Format.RGB, Texture.Type.FLOAT)
        tex.generatePrefilterMipmap(engine, pbd, IntArray(6) { it * face }, Texture.PrefilterOptions())
        return tex
    }
}
