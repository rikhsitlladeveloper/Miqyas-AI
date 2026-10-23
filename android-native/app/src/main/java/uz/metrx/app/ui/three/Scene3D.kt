package uz.metrx.app.ui.three

import android.graphics.Bitmap
import android.view.ViewGroup
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.google.android.filament.Camera
import com.google.android.filament.Colors
import com.google.android.filament.Engine
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderableManager
import com.google.android.filament.View
import dev.romainguy.kotlin.math.Float3
import io.github.sceneview.FrameRatePolicy
import io.github.sceneview.RenderInvalidator
import io.github.sceneview.RenderQuality
import io.github.sceneview.SceneView
import io.github.sceneview.SurfaceType
import io.github.sceneview.environment.Environment
import io.github.sceneview.geometries.Geometry
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.colorOf
import io.github.sceneview.node.CameraNode
import io.github.sceneview.node.GeometryNode
import io.github.sceneview.node.Node
import io.github.sceneview.rememberEnvironment
import io.github.sceneview.rememberEnvironmentLoader
import io.github.sceneview.rememberMaterialLoader
import io.github.sceneview.rememberRenderInvalidator
import io.github.sceneview.rememberView
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import uz.metrx.app.geo.Bounds
import uz.metrx.app.geo.FOV_HALF
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.WALL_INK
import uz.metrx.app.geo.shade
import uz.metrx.app.geo.v3Fit
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.ui
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.tan

/*
 * The 3D picture (prototype mount3D / draw3D and the ux module's camera limits), drawn with SceneView.
 * The colours are worked out here the way three.js lights the prototype's Lambert walls, and handed to
 * Filament as flat colours with its post-processing off, so the picture matches the prototype's.
 */

const val BG3D = 0xF3F6FA

/**
 * One Filament engine (and its GL context) for the whole app: SceneView would make and destroy one per 3D screen,
 * and on the emulator tearing GL contexts down and up again crashed the PC's graphics driver.
 */
object Engine3D { val engine: Engine by lazy { io.github.sceneview.createEngine(io.github.sceneview.createEglContext()) } }

/** Where the camera is and where it may go. One per 3D picture. */
class Cam3D {
    var theta = PI / 2 + .75; var phi = .95; var r = 12.0
    /** "From the corner" turns the camera back to this (a corner piece with its corner on the left is seen from the right). */
    var cornerTheta = PI / 2 + .75
    var tgt = V3(0.0, 1.0, 0.0)
    var bounds: Bounds? = null; var rMin = 3.0; var rMax: Double? = null
    var fit: DoubleArray? = null; var rFit: Double? = null
    var dims = doubleArrayOf(1.0, 1.0, 1.0)
    var w = 0; var h = 0
    /** The room the view is zoomed to (several rooms). */
    var focus by mutableStateOf<String?>(null)
    /** Bumped on every move, so the labels follow. */
    var tick by mutableIntStateOf(0)
    internal var onMove: (() -> Unit)? = null
    internal var anim: Job? = null
    private var shellKey: List<Double>? = null

    val aspect get() = if (w > 0 && h > 0) w.toDouble() / h else 1.0

    /** A new scene: the camera starts over unless only colours changed (the prototype starts over on every rebuild). */
    fun load(s: Shell3D) {
        // a tiler's tiles changing is not a new room: the camera stays
        val key = listOf(s.L, s.W, s.H, s.parts.count { !it.tile }.toDouble())
        if (key == shellKey) return
        shellKey = key
        anim?.cancel(); focus = null
        dims = doubleArrayOf(s.L, s.W, s.H)
        tgt = s.tgt; r = s.r; s.theta?.let { theta = it }; s.phi?.let { phi = it }
        cornerTheta = s.theta ?: PI / 2 + .75
        bounds = s.bounds; rMin = s.rMin; rMax = null; fit = s.fit; rFit = null
        if (w > 0) applyFit()
        moved()
    }

    fun resize(w: Int, h: Int) { this.w = w; this.h = h; if (fit != null) applyFit(); moved() }

    /** The distance that shows everything depends on the shape of the picture (prototype resize3D). */
    private fun applyFit() {
        val f = fit ?: return
        r = v3Fit(f[0], f[1], f[2], aspect) * f[3]; rFit = r; rMax = r * f[4]; fit = null
    }

    private fun clamp() {
        bounds?.let { b -> tgt = V3(tgt.x.coerceIn(b.x0, max(b.x0, b.x1)), tgt.y, tgt.z.coerceIn(b.z0, max(b.z0, b.z1))) }
        rMax?.let { r = r.coerceIn(rMin, max(rMin, it)) }
    }

    fun eye() = V3(tgt.x + r * sin(phi) * cos(theta), tgt.y + r * cos(phi), tgt.z + r * sin(phi) * sin(theta))

    fun moved() { clamp(); onMove?.invoke(); tick++ }

    /** One finger turns the view (prototype: 0.009 per pixel). */
    fun rotate(dx: Float, dy: Float) { theta += dx * .009; phi = (phi - dy * .009).coerceIn(.06, 1.5); moved() }

    /** Pinch: [k] is the old finger distance over the new one. */
    fun zoom(k: Double) { r = (r * k).coerceIn(3.0, 80.0); moved() }

    /** Two fingers move the view across the floor (prototype v3Pan); dx, dy in pixels. */
    fun pan(dx: Float, dy: Float) {
        val hh = if (h > 0) h.toDouble() else 400.0
        val k = 2 * r * tan(FOV_HALF) / hh; val kf = k / max(.35, cos(phi)); val th = theta
        tgt = V3(tgt.x - sin(th) * dx * k - cos(th) * dy * kf, tgt.y, tgt.z + cos(th) * dx * k - sin(th) * dy * kf)
        moved()
    }

    /** "From above" and "From the corner": back to the middle at the start distance (prototype preset + ux). */
    fun preset(top: Boolean) {
        anim?.cancel()
        if (top) { phi = .07; theta = PI / 2 } else { phi = .95; theta = cornerTheta }
        tgt = V3(dims[0] / 2, dims[2] * .3, dims[1] / 2)
        r = rFit ?: (max(dims[0], dims[1]) * 2.2 + 2.5)
        moved()
    }

    /** Where a point appears in the picture, in pixels; null behind the camera. */
    fun project(p: V3): Offset? {
        if (w == 0 || h == 0) return null
        val e = eye(); val f = (tgt - e).unit()
        val s = cross(f, V3(0.0, 1.0, 0.0)).unit()
        val u = cross(s, f)
        val d = p - e
        val zc = d.dot(f); if (zc <= .1) return null
        val fy = 1 / tan(FOV_HALF); val fx = fy / aspect
        val nx = fx * d.dot(s) / zc; val ny = fy * d.dot(u) / zc
        return Offset(((nx + 1) / 2 * w).toFloat(), ((1 - ny) / 2 * h).toFloat())
    }

    /** The ray from the eye through pixel ([x], [y]): its start and direction (the inverse of [project]). */
    fun ray(x: Float, y: Float): Pair<V3, V3> {
        val e = eye(); val f = (tgt - e).unit()
        val s = cross(f, V3(0.0, 1.0, 0.0)).unit()
        val u = cross(s, f)
        val k = tan(FOV_HALF)
        val nx = 2.0 * x / max(1, w) - 1; val ny = 1 - 2.0 * y / max(1, h)
        return e to (f + s * (nx * k * aspect) + u * (ny * k)).unit()
    }

    private fun cross(a: V3, b: V3) = V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

/** Filament's camera with the prototype's lens: 40° high, 0.1 to [far] metres. */
private class Lens(engine: Engine) : CameraNode(engine) {
    var farM = 300f
    override fun updateProjection(focalLength: Double, near: Float, far: Float, aspect: Double) {
        if (view != null) setProjection(40.0, .1f, farM, Camera.Fov.VERTICAL, aspect)
    }
}

/** The SceneView nodes of a shell and the cut-away of the walls that face the camera (prototype draw3D). */
private class ShellNodes(val engine: Engine, val ml: MaterialLoader) {
    private class Prim(val node: GeometryNode, val index: Int, val rgb: Int, val op: Float, val role: Role, val group: Int, val wall: String?) { var alpha = -1f }
    private class Line(val node: GeometryNode, val group: Int, val wall: String) { var alpha = -1f }
    private val mats = HashMap<Long, MaterialInstance>()
    private val prims = ArrayList<Prim>(); private val lines = ArrayList<Line>()
    private val nodes = ArrayList<Node>()
    private var shell: Shell3D? = null

    /** A flat colour; see-through ones are handed over divided by their opacity, which Filament applies twice. */
    fun mat(rgb: Int, alpha: Float): MaterialInstance = mats.getOrPut((rgb.toLong() shl 8) or (alpha * 255).toLong()) {
        val r = ((rgb shr 16) and 255) / 255f; val g = ((rgb shr 8) and 255) / 255f; val b = (rgb and 255) / 255f
        ml.createUnlitColorInstance(colorOf(r, g, b, alpha)).apply {
            val k = if (alpha < 1f) 1f / alpha else 1f
            setParameter("color", Colors.RgbaType.LINEAR, r * k, g * k, b * k, alpha)
            if (alpha < 1f) setDepthWrite(false)
            setCullingMode(com.google.android.filament.Material.CullingMode.BACK)
        }
    }

    fun clear(root: Node) {
        nodes.forEach { root.removeChildNode(it); it.destroy() }
        nodes.clear(); prims.clear(); lines.clear()
    }

    fun build(root: Node, s: Shell3D) {
        clear(root); shell = s
        // faces, one node per piece, one primitive per lit colour
        s.parts.forEach { p ->
            if (p.faces.isEmpty()) return@forEach
            val byColor = LinkedHashMap<Int, ArrayList<uz.metrx.app.geo.Face>>()
            p.faces.forEach { f -> byColor.getOrPut(shade(p.rgb, f.n, s.light)) { ArrayList() } += f }
            val verts = ArrayList<Geometry.Vertex>(); val prim = ArrayList<List<Int>>(); val colors = ArrayList<Int>()
            byColor.forEach { (c, fs) ->
                val idx = ArrayList<Int>()
                fs.forEach { f ->
                    val base = verts.size
                    val n = Float3(f.n.x.toFloat(), f.n.y.toFloat(), f.n.z.toFloat())
                    f.pts.forEach { q -> verts += Geometry.Vertex(position = Float3(q.x.toFloat(), q.y.toFloat(), q.z.toFloat()), normal = n) }
                    val tris = f.tris ?: (1 until f.pts.size - 1).flatMap { listOf(0, it, it + 1) }
                    for (t in tris.indices step 3) {
                        val a = f.pts[tris[t]]; val b = f.pts[tris[t + 1]]; val cc = f.pts[tris[t + 2]]
                        val cr = (b - a).let { u -> (cc - a).let { v -> V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x) } }
                        if (cr.dot(f.n) >= 0) { idx += base + tris[t]; idx += base + tris[t + 1]; idx += base + tris[t + 2] }
                        else { idx += base + tris[t]; idx += base + tris[t + 2]; idx += base + tris[t + 1] }
                    }
                }
                prim += idx; colors += c
            }
            val geo = Geometry.Builder().vertices(verts).primitivesIndices(prim).build(engine)
            val node = GeometryNode(engine, geo, colors.map { mat(it, p.op) }, geo.primitivesOffsets)
            colors.forEachIndexed { i, c -> prims += Prim(node, i, c, p.op, p.role, p.group, p.wall) }
            root.addChildNode(node); nodes += node
        }
        // the dark wall outlines
        s.edges.forEach { e ->
            if (e.segs.isEmpty()) return@forEach
            val geo = Geometry.Builder(RenderableManager.PrimitiveType.LINES)
                .vertices(e.segs.map { Geometry.Vertex(position = Float3(it.x.toFloat(), it.y.toFloat(), it.z.toFloat())) })
                .indices(e.segs.indices.toList()).build(engine)
            val node = GeometryNode(engine, geo, mat(WALL_INK, 1f))
            lines += Line(node, e.group, e.wall); root.addChildNode(node); nodes += node
        }
        // the floor grid (three.js GridHelper: the middle lines darker)
        run {
            val half = s.gridSize / 2; val step = s.gridSize / s.gridDiv; val center = if (s.gridDiv % 2 == 0) s.gridDiv / 2 else -1
            val v = ArrayList<Geometry.Vertex>(); val mid = ArrayList<Int>(); val rest = ArrayList<Int>()
            for (i in 0..s.gridDiv) {
                val k = (-half + i * step).toFloat(); val y = -.002f
                val x0 = (s.gridCx - half).toFloat(); val x1 = (s.gridCx + half).toFloat(); val z0 = (s.gridCz - half).toFloat(); val z1 = (s.gridCz + half).toFloat()
                val list = if (i == center) mid else rest
                list += v.size; v += Geometry.Vertex(position = Float3(x0, y, s.gridCz.toFloat() + k)); list += v.size; v += Geometry.Vertex(position = Float3(x1, y, s.gridCz.toFloat() + k))
                list += v.size; v += Geometry.Vertex(position = Float3(s.gridCx.toFloat() + k, y, z0)); list += v.size; v += Geometry.Vertex(position = Float3(s.gridCx.toFloat() + k, y, z1))
            }
            val ps = listOf(mid, rest).filter { it.isNotEmpty() }
            val cs = listOf(0xC3CEDF to mid, 0xDCE4F0 to rest).filter { it.second.isNotEmpty() }.map { it.first }
            val geo = Geometry.Builder(RenderableManager.PrimitiveType.LINES).vertices(v).primitivesIndices(ps).build(engine)
            val node = GeometryNode(engine, geo, cs.map { mat(it, 1f) }, geo.primitivesOffsets)
            root.addChildNode(node); nodes += node
        }
    }

    /** Walls between the camera and the room's middle become see-through (prototype draw3D). */
    fun cutaway(eye: V3, phi: Double) {
        val s = shell ?: return
        val top = phi < .35
        fun facing(g: Int, w: String?): Boolean {
            if (top || w == null) return false
            val gp = s.groups.getOrNull(g) ?: return false; val n = gp.normals[w] ?: return false
            val dx = eye.x - gp.cx; val dz = eye.z - gp.cz
            return dx * n.first + dz * n.second > .4 * hypot(dx, dz)
        }
        // the wall facing the eye goes see-through, its doors and windows with it; the furniture on it stays solid
        prims.forEach { p ->
            val f = facing(p.group, p.wall)
            val a = when (p.role) { Role.WALL -> if (f) .14f else 1f; Role.OPENING -> if (f) min(.12f, p.op) else p.op; Role.FURN -> p.op; else -> p.op }
            if (a != p.alpha) { p.alpha = a; p.node.setMaterialInstanceAt(p.index, mat(p.rgb, a)) }
        }
        lines.forEach { l ->
            val a = if (facing(l.group, l.wall)) .35f else 1f
            if (a != l.alpha) { l.alpha = a; l.node.setMaterialInstanceAt(0, mat(WALL_INK, a)) }
        }
    }
}

/** Hands the screenshot of the picture to "Add to report" (read back from the 3D surface, without the labels). */
class Shot3D {
    internal var grab: ((Bitmap?) -> Unit) -> Unit = { it(null) }
    fun take(done: (Bitmap?) -> Unit) = grab(done)
}

/**
 * The 3D picture of [shell]. One finger turns it, two fingers move it and pinch zooms, inside the ux module's limits.
 * [overlay] draws on top (labels are positioned with [Cam3D.project]).
 */
@Composable
fun Scene3D(shell: Shell3D, cam: Cam3D, modifier: Modifier = Modifier, shot: Shot3D? = null, onTap: ((Offset) -> Unit)? = null, overlay: @Composable BoxScope.() -> Unit = {}) {
    val engine = Engine3D.engine
    val ml = rememberMaterialLoader(engine)
    val el = rememberEnvironmentLoader(engine)
    val view = rememberView(engine)
    val env = rememberEnvironment(el) { Environment() }
    val lens = remember(engine) { Lens(engine).apply { setExposure(1f) } }
    // the engine outlives this screen, so its camera is let go here (after SceneView has let go of it)
    DisposableEffect(lens) { onDispose { runCatching { lens.destroy() } } }
    val inv: RenderInvalidator = rememberRenderInvalidator()
    val nodes = remember(engine) { ShellNodes(engine, ml) }
    var root by remember { mutableStateOf<Node?>(null) }
    val host = LocalView.current
    val density = LocalDensity.current.density

    fun push() {
        val e = cam.eye()
        lens.lookAt(Float3(e.x.toFloat(), e.y.toFloat(), e.z.toFloat()), Float3(cam.tgt.x.toFloat(), cam.tgt.y.toFloat(), cam.tgt.z.toFloat()), Float3(0f, 1f, 0f))
        nodes.cutaway(e, cam.phi)
        inv.requestRender()
    }

    Box(modifier.background(Color(0xFF000000.toInt() or BG3D)).onSizeChanged { cam.resize(it.width, it.height) }) {
        SceneView(
            Modifier.fillMaxSize(), surfaceType = SURFACE, engine = engine, materialLoader = ml, environmentLoader = el,
            view = view, isOpaque = true, frameRatePolicy = FrameRatePolicy.OnDemand(), renderInvalidator = inv, renderQuality = RenderQuality.Default,
            autoCenterContent = false, environment = env, mainLightNode = null, fillLightNode = null, cameraNode = lens,
            cameraManipulator = null, onGestureListener = null
        ) {
            Node(apply = { root = this })
        }
        // the background is a flat panel carried by the camera: Filament's own clear colour comes out a shade off
        DisposableEffect(lens) {
            val q = listOf(Float3(-2000f, -2000f, -280f), Float3(2000f, -2000f, -280f), Float3(2000f, 2000f, -280f), Float3(-2000f, 2000f, -280f))
            val g = Geometry.Builder().vertices(q.map { Geometry.Vertex(position = it, normal = Float3(0f, 0f, 1f)) }).indices(listOf(0, 1, 2, 0, 2, 3)).build(engine)
            val bg = GeometryNode(engine, g, nodes.mat(BG3D, 1f))
            lens.addChildNode(bg)
            onDispose { lens.removeChildNode(bg); bg.destroy() }
        }
        LaunchedEffect(view) {
            // after SceneView's own quality preset: plain colours, smooth edges, nothing else
            view.renderQuality = view.renderQuality.apply { hdrColorBuffer = View.QualityLevel.HIGH }
            view.ambientOcclusionOptions = view.ambientOcclusionOptions.apply { enabled = false }
            view.bloomOptions = view.bloomOptions.apply { enabled = false }
            view.dynamicResolutionOptions = view.dynamicResolutionOptions.apply { enabled = false }
            view.multiSampleAntiAliasingOptions = view.multiSampleAntiAliasingOptions.apply { enabled = true; sampleCount = 4 }
            view.antiAliasing = View.AntiAliasing.NONE
            view.dithering = View.Dithering.NONE
            view.setShadowingEnabled(false)
            view.isPostProcessingEnabled = false
            inv.requestRender()
        }
        LaunchedEffect(root, shell) {
            val rt = root ?: return@LaunchedEffect
            lens.farM = shell.far.toFloat(); lens.updateProjection()
            nodes.build(rt, shell)
            cam.onMove = ::push
            cam.load(shell)
            push()
        }
        DisposableEffect(Unit) { onDispose { cam.onMove = null; cam.anim?.cancel(); root?.let { nodes.clear(it) } } }
        if (shot != null) DisposableEffect(shot) {
            shot.grab = { done ->
                val tv = findTexture(host.rootView)
                val sv = findSurface(host.rootView)
                if (tv != null) done(runCatching { tv.bitmap }.getOrNull())
                else if (sv == null || sv.width == 0 || sv.height == 0) done(null)
                else {
                    val bmp = Bitmap.createBitmap(sv.width, sv.height, Bitmap.Config.ARGB_8888)
                    runCatching {
                        android.view.PixelCopy.request(sv, bmp, { res -> done(if (res == android.view.PixelCopy.SUCCESS) bmp else null) }, android.os.Handler(android.os.Looper.getMainLooper()))
                    }.onFailure { done(null) }
                }
            }
            onDispose { shot.grab = { it(null) } }
        }
        // fingers
        Box(Modifier.fillMaxSize().pointerInput(cam, onTap) {
            awaitEachGesture {
                val first = awaitFirstDown(requireUnconsumed = false)
                cam.anim?.cancel()
                val last = HashMap<Long, Offset>(); last[first.id.value] = first.position
                // a short touch that hardly moves with one finger is a tap (it opens a door)
                var moved = 0f; var fingers = 1
                val t0 = first.uptimeMillis
                while (true) {
                    val ev = awaitPointerEvent()
                    val down = ev.changes.filter { it.pressed }
                    fingers = max(fingers, down.size)
                    ev.changes.firstOrNull { it.id == first.id }?.let { moved = max(moved, (it.position - first.position).getDistance()) }
                    if (down.isEmpty()) {
                        val up = ev.changes.firstOrNull()?.uptimeMillis ?: t0
                        if (onTap != null && fingers == 1 && moved < 12 * density && up - t0 < 450) onTap(first.position)
                        break
                    }
                    if (down.size >= 2) {
                        val a = down[0]; val b = down[1]
                        val pa = last[a.id.value] ?: a.position; val pb = last[b.id.value] ?: b.position
                        val d0 = (pa - pb).getDistance(); val d1 = (a.position - b.position).getDistance()
                        if (d0 > 0 && d1 > 0) cam.zoom((d0 / d1).toDouble())
                        val m0 = (pa + pb) / 2f; val m1 = (a.position + b.position) / 2f
                        cam.pan(m1.x - m0.x, m1.y - m0.y)
                    } else {
                        val c = down[0]; val p = last[c.id.value]
                        if (p != null) cam.rotate((c.position.x - p.x) / density, (c.position.y - p.y) / density)
                    }
                    last.clear(); ev.changes.forEach { ch: PointerInputChange -> if (ch.pressed) last[ch.id.value] = ch.position; ch.consume() }
                }
            }
        })
        overlay()
    }
}

/**
 * Where the 3D is drawn. A SurfaceView on the emulator (the TextureView path crashed the PC's graphics driver after a
 * few openings) and on Android 10 and newer. Older phones get a TextureView: there a SurfaceView ignores the page's
 * clipping, and on the founder's Mi 6X (Android 8.1) the order page's header went black above the 3D view.
 */
private val SURFACE: SurfaceType = run {
    val emu = android.os.Build.FINGERPRINT.startsWith("generic") || android.os.Build.FINGERPRINT.contains("emulator") ||
        android.os.Build.HARDWARE.contains("ranchu") || android.os.Build.HARDWARE.contains("goldfish") || android.os.Build.PRODUCT.contains("sdk_gphone")
    if (!emu && android.os.Build.VERSION.SDK_INT < 29) SurfaceType.TextureSurface else SurfaceType.Surface
}

/** The 3D picture on screen when it is a TextureView (older phones). */
private fun findTexture(v: android.view.View): android.view.TextureView? {
    if (v is android.view.TextureView && v.isShown) return v
    if (v is ViewGroup) for (i in 0 until v.childCount) findTexture(v.getChildAt(i))?.let { return it }
    return null
}

/** The 3D surface on screen (the only SurfaceView in the app). */
private fun findSurface(v: android.view.View): android.view.SurfaceView? {
    if (v is android.view.SurfaceView && v.isShown) return v
    if (v is ViewGroup) for (i in 0 until v.childCount) findSurface(v.getChildAt(i))?.let { return it }
    return null
}

/** Moves the camera smoothly to a room or back to all of them (prototype v3Go: 340 ms, easing out). */
fun Cam3D.go(scope: kotlinx.coroutines.CoroutineScope, t: V3, r1: Double, th: Double? = null, ph: Double? = null) {
    anim?.cancel()
    val t0 = tgt; val r0 = r; val th0 = theta; val ph0 = phi
    anim = scope.launch {
        val k = Animatable(0f)
        k.animateTo(1f, tween(340, easing = CubicBezierEasing(.33f, 1f, .68f, 1f))) {
            val e = value.toDouble()
            tgt = V3(t0.x + (t.x - t0.x) * e, t0.y + (t.y - t0.y) * e, t0.z + (t.z - t0.z) * e); r = r0 + (r1 - r0) * e
            if (th != null && ph != null) { theta = th0 + (th - th0) * e; phi = ph0 + (ph - ph0) * e }
            moved()
        }
    }
}

/** Labels placed at points of the picture, each centred on its point. */
@Composable
fun BoxScope.Labels3D(cam: Cam3D, points: List<V3>, content: @Composable (Int) -> Unit) {
    @Suppress("UNUSED_VARIABLE") val t = cam.tick
    val at = points.map { cam.project(it) }
    Layout(content = { points.indices.forEach { i -> if (at[i] != null) Box { content(i) } } }, modifier = Modifier.fillMaxSize().clipToBounds()) { ms, c ->
        val pl = ms.map { it.measure(c.copy(minWidth = 0, minHeight = 0)) }
        // kept inside the picture, under the buttons along its top (a wall letter must not sit on the tabs above or under a button)
        val top = 56.dp.roundToPx(); val pad = 4.dp.roundToPx()
        layout(c.maxWidth, c.maxHeight) {
            var j = 0
            points.indices.forEach { i -> val p = at[i] ?: return@forEach; val q = pl[j++]
                val x = (p.x - q.width / 2f).toInt().coerceIn(pad, maxOf(pad, c.maxWidth - q.width - pad))
                val y = (p.y - q.height / 2f).toInt().coerceIn(minOf(top, maxOf(0, c.maxHeight - q.height)), maxOf(top, c.maxHeight - q.height - pad))
                q.place(x, y) }
        }
    }
}

/** The labels' ink: they are white in dark mode too, so their text and rim stay dark. */
private val LBL_INK = Color(0xFF0F172A)

/** A wall letter or a room name over the picture (prototype .three .lbl). */
@Composable
fun Lbl3D(text: String) {
    Box(
        Modifier.defaultMinSize(minWidth = 24.dp).height(24.dp).clip(RoundedCornerShape(12.dp)).background(Color.White)
            .border(1.33.dp, LBL_INK, RoundedCornerShape(12.dp)).padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center
    ) { Text(text, style = ui(12f, 600, LBL_INK), maxLines = 1) }
}

/** A room name that zooms to the room (ux .lbl.go); [on] while the view is on that room. The touch area reaches past it. */
@Composable
fun RoomLbl3D(text: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        Modifier.clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null,
            role = androidx.compose.ui.semantics.Role.Button, onClick = onClick).padding(horizontal = 4.dp, vertical = 9.dp),
        contentAlignment = Alignment.Center
    ) {
        Box(
            Modifier.dropShadow(shape, Shadow(8.dp, Color(0x1F101828), offset = DpOffset(0.dp, 2.dp)))
                .defaultMinSize(minHeight = 28.dp).clip(shape).background(if (on) G.cobalt else Color.White)
                .border(1.33.dp, if (on) G.cobalt else LBL_INK, shape).padding(horizontal = 10.dp),
            contentAlignment = Alignment.Center
        ) { Text(text, style = ui(12.5f, 700, if (on) Color.White else LBL_INK), maxLines = 1) }
    }
}
