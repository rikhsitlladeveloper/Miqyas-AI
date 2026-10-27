package uz.metrx.app.ui.furniture

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import kotlinx.coroutines.launch
import uz.metrx.app.furniture.LOOK_COLOURS
import uz.metrx.app.furniture.LOOK_WOODS
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.icons.ICONS
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * Designer C v2 (founder-approved mockup design/designer-c/mockup.html, 27 Oct 2026): the parts every cabinet designer
 * shares. The drawing is edited directly (tap selects, a second tap a door or drawer, hold ~0.4 s to move, drag the
 * edge to resize, one finger pans, two zoom, double tap fits); a Canva-style slider of tools at the bottom changes with
 * the selection and a tool opens its options in its place with a ← back. Here: the editor's state, the view's zoom and
 * pan, the gestures, the slider and option rows, the caption, the callout, the number sheet and the first-time hint.
 */

/* ---------------- state ---------------- */

/** What is selected: a module (a kitchen unit, a gap, the free end "#end:<wall>:<row>", a section's index) and maybe one of its fronts. */
data class DSel(val id: String, val front: Int? = null)

/** The editor's state for one piece, kept while the app runs (KitOps.dz). */
class DzcState {
    var sel by mutableStateOf<DSel?>(null)
    /** The tool whose options replace the slider; null: the slider. */
    var strip by mutableStateOf<String?>(null)
    /** "one", "row", "all": where Fasad, Tutqich, Yumshoq yopilish and Chuqurlik apply. */
    var scope by mutableStateOf("one")
    var multi by mutableStateOf(false)
    var ticks by mutableStateOf(setOf<String>())
    /** "Ichini ko‘rish": every door open in the drawing; [peek] the selected module's only. */
    var inside by mutableStateOf(false)
    var peek by mutableStateOf<String?>(null)
    /** Qo‘shish's category. */
    var cat by mutableStateOf("door")
    /** The check's callout folded to its "!" badge. */
    var cmin by mutableStateOf(false)
    /** The first-time hint on screen. */
    var teach by mutableStateOf(false)
    /** The view: zoom over the fitted drawing and the pan, in viewBox units. */
    var z by mutableFloatStateOf(1f)
    var px by mutableFloatStateOf(0f)
    var py by mutableFloatStateOf(0f)
    val fit get() = z == 1f && px == 0f && py == 0f
    fun fitNow() { z = 1f; px = 0f; py = 0f }
    /** The last tap (time, x, y) for the double tap. */
    var lastTap = Triple(0L, 0f, 0f)
    fun clear() { sel = null; strip = null; peek = null; scope = "one" }
    fun pick(s: DSel?) { sel = s; scope = "one" }
}

/** The editor's state of piece [fid]. */
fun App.dzc(fid: String): DzcState = kit.dz.getOrPut(fid) { DzcState() }

/** The view's mapping: the fitted drawing's offset and scale on screen ([u] px a viewBox unit). */
class DzcView(val ox: Float, val oy: Float, val u: Float) {
    /** A screen point in the zoomed viewBox. */
    fun v(p: Offset) = Offset((p.x - ox) / u, (p.y - oy) / u)
    fun sx(vx: Float) = ox + vx * u
    fun sy(vy: Float) = oy + vy * u
}

/** The fit of a viewBox [vw] × [vh] into [w] × [h] px with [top] and [bottom] px kept free (the caption, the slider). */
fun dzcFit(vw: Float, vh: Float, w: Float, h: Float, top: Float, bottom: Float): DzcView {
    val ah = max(60f, h - top - bottom)
    val u = min((w - 16f) / vw, ah / vh)
    return DzcView((w - vw * u) / 2f, top + (ah - vh * u) / 2f, u)
}

/** Pinch about [c] (screen px) by [f]: the point under the fingers stays put. Zoom from 0.7× to 6×. */
fun DzcState.zoomAt(view: DzcView, c: Offset, f: Float) {
    val v = view.v(c)
    // the point in the unzoomed viewBox
    val bx = (v.x - px) / z; val by = (v.y - py) / z
    val nz = (z * f).coerceIn(.7f, 6f)
    px = v.x - nz * bx; py = v.y - nz * by; z = nz
}

/** Zoomed in past 2.5×: the edge moves in 10 mm steps. */
val DzcState.fine get() = z > 2.5f

/* ---------------- gestures ---------------- */

/** What the canvas does with the fingers (2D). */
interface DzcGestures {
    /** A handle of the selection under [p] ("w" its right edge, "h" a wall unit's bottom edge), null: none. */
    fun handleAt(p: Offset): String?
    /** Whether a long-press at [p] lifts a module. */
    fun liftable(p: Offset): Boolean
    fun tap(p: Offset)
    fun doubleTap()
    fun pressStart(p: Offset) {}
    fun pressEnd() {}
    fun lift(p: Offset)
    fun moveTo(p: Offset)
    fun drop(cancel: Boolean)
    fun handleStart(kind: String, p: Offset)
    fun handleTo(p: Offset)
    fun handleEnd(cancel: Boolean)
    fun pan(d: Offset)
    fun zoom(c: Offset, f: Float)
}

/** How long a press lifts a module (ms). */
const val LIFT_MS = 400L

/**
 * The canvas's fingers: a handle drags at once; a quick drag pans; holding [LIFT_MS] on a module lifts it to move it;
 * two fingers zoom (cancelling a lift or a resize); a tap selects; two taps fit.
 */
suspend fun PointerInputScope.dzcGestures(g: DzcGestures) {
    val slop = viewConfiguration.touchSlop
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val h = g.handleAt(down.position)
        var mode = if (h != null) "handle" else "tap"
        if (h != null) { down.consume(); g.handleStart(h, down.position) }
        val canLift = h == null && g.liftable(down.position)
        if (canLift) g.pressStart(down.position)
        val t0 = down.uptimeMillis
        var last = t0
        while (true) {
            val ev = if (mode == "tap" && canLift) withTimeoutOrNull((LIFT_MS - (last - t0)).coerceAtLeast(1L)) { awaitPointerEvent() }
                else awaitPointerEvent()
            ev?.changes?.firstOrNull()?.let { last = it.uptimeMillis }
            if (ev == null) { mode = "move"; g.pressEnd(); g.lift(down.position); continue }
            val pressed = ev.changes.filter { it.pressed }
            if (pressed.size >= 2) {
                if (mode == "move") g.drop(true)
                if (mode == "handle") g.handleEnd(true)
                if (mode == "tap" && canLift) g.pressEnd()
                mode = "pinch"
                val zf = ev.calculateZoom(); val c = ev.calculateCentroid(useCurrent = true)
                if (zf != 1f && c != Offset.Unspecified) g.zoom(c, zf)
                val pan = pressed.fold(Offset.Zero) { a, ch -> a + ch.positionChange() } / pressed.size.toFloat()
                if (pan != Offset.Zero) g.pan(pan)
                ev.changes.forEach { it.consume() }
                continue
            }
            val ch = ev.changes.firstOrNull { it.id == down.id }
            if (ch == null || !ch.pressed) {
                when (mode) {
                    "tap" -> { if (canLift) g.pressEnd(); g.tap(down.position) }
                    "move" -> g.drop(false)
                    "handle" -> g.handleEnd(false)
                    "pan" -> {}
                    "pinch" -> if (pressed.isEmpty()) break
                }
                break
            }
            when (mode) {
                "tap" -> if ((ch.position - down.position).getDistance() > slop) { if (canLift) g.pressEnd(); mode = "pan"; g.pan(ch.position - down.position) }
                "pan" -> g.pan(ch.positionChange())
                "move" -> g.moveTo(ch.position)
                "handle" -> g.handleTo(ch.position)
                "pinch" -> {}
            }
            ch.consume()
        }
    }
}

/* ---------------- icons ---------------- */

/** The designer's tool icons (24 × 24 strokes, from the approved mockup); any other name is the app's sprite's. */
private val DZ_ICONS = mapOf(
    "back" to "M15 5l-7 7 7 7",
    "plus" to "M12 5v14M5 12h14",
    "trash" to "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
    "close" to "M6 6l12 12M18 6L6 18",
    "palette" to "M12 3a9 9 0 1 0 0 18c1.2 0 2-.8 2-2 0-.6-.3-1-.6-1.4-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2H17a4 4 0 0 0 4-4c0-4.1-4-7.3-9-7.3z M7.5 11.5h.01M10.5 7.5h.01M15 7.5h.01",
    "handle" to "M5 9h14M7 9v4M17 9v4",
    "grid" to "M4 4h16v16H4z M4 10h16M4 15h16",
    "shelves" to "M4 3h16v18H4z M4 9h16M4 15h16",
    "eye" to "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
    "tick" to "M3 3h8v8H3z M5 7l1.5 1.5L9.5 5.5 M13 13h8v8h-8z M15 17l1.5 1.5 3-3 M13 3h8v8h-8z",
    "warn" to "M12 3l10 18H2z M12 10v5M12 18h.01",
    "height" to "M12 3v18M8 7l4-4 4 4M8 17l4 4 4-4",
    "align" to "M5 4h14v6H5z M8 14h8v6H8z M5 12h2M9 12h2M13 12h2M17 12h2",
    "hinge" to "M5 3h14v18H5z M19 3L7 12l12 9",
    "ruler" to "M3 17L17 3l4 4L7 21z M7 13l2 2M10 10l2 2M13 7l2 2",
    "kbd" to "M3 6h18v12H3z M7 10h.01M11 10h.01M15 10h.01M7 14h10",
    "fit" to "M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5",
    "cols" to "M3 4h18v16H3z M9 4v16M15 4v16",
    "left" to "M15 5l-7 7 7 7",
    "right" to "M9 5l7 7-7 7",
    "up" to "M6 15l6-6 6 6",
    "soft" to "M4 12h6M14 12h6M10 8l4 4-4 4",
    "copy" to "M8 8h12v12H8z M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3",
    "move" to "M3 12h18M7 8l-4 4 4 4M17 8l4 4-4 4",
    "depth" to "M4 9l8-5 8 5-8 5z M4 9v6l8 5 8-5V9 M12 14v6",
    "plinth" to "M4 3h16v13H4z M4 19h16M7 16v3M17 16v3",
    "style" to "M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6L3.4 9.3l6-.7z",
    "closeg" to "M3 12h7M14 12h7M7 8l4 4-4 4M17 8l-4 4 4 4",
    "doorT" to "M6 3h12v18H6z M15 11v3",
    "chk" to "M5 12.5l4.5 4.5L19 7"
)
private val dzPaths = HashMap<String, Path>()

@Composable
fun DzIcon(name: String, color: Color, size: Dp = 22.dp, stroke: Float = 2f) {
    val d = DZ_ICONS[name]
    if (d == null) { MIcon(name, color, size, stroke); return }
    Canvas(Modifier.size(size)) {
        val k = this.size.minDimension / 24f
        val p = dzPaths.getOrPut(d) { PathParser().parsePathString(d).toPath() }
        scale(k, k, pivot = Offset.Zero) { drawPath(p, color, style = Stroke(stroke, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
    }
}

/** The small pictures on the option chips (30 × 30 strokes, the mockup's glyphs). */
private val DZ_GLYPHS = mapOf(
    "door1" to "M7 4h16v22H7z M19 9v5",
    "door2" to "M4 4h22v22H4z M15 4v22M12.5 9v4M17.5 9v4",
    "drawer2" to "M4 4h22v22H4z M4 15h22M12 8h6M12 19h6",
    "drawer3" to "M4 4h22v22H4z M4 11h22M4 18.5h22M12 7.5h6M12 14.5h6M12 22h6",
    "drawer4" to "M4 4h22v22H4z M4 9.5h22M4 15h22M4 20.5h22",
    "open" to "M4 4h22v22H4z M4 11h22M4 18h22",
    "sink" to "M4 11h22v15H4z M15 11V5h5v3M8 11h14",
    "hob" to "M4 8h22v18H4z M4 5h22 M8 13h14v8H8z",
    "dw" to "M4 4h22v22H4z M10 8h10 M12 17a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
    "wdoor1" to "M7 4h16v13H7z M19 12v3",
    "wdoor2" to "M4 4h22v13H4z M15 4v13M13 13v2M17 13v2",
    "wglass" to "M4 4h22v14H4z M15 4v14M7 15l4-7M18 15l4-7",
    "wopen" to "M4 4h22v14H4z M4 11h22",
    "door" to "M8 2h14v26H8z M18 13v4",
    "mirror" to "M8 2h14v26H8z M11 12l5-6M11 20l8-9",
    "glass" to "M8 2h14v26H8z M11 8h8v14h-8z",
    "sopen" to "M8 2h14v26H8z M8 9h14M8 17h14",
    "plinth" to "M4 4h22v17H4z M4 21h22v5H4z",
    "legs" to "M4 4h22v17H4z M8 21v5M22 21v5",
    "metal" to "M4 4h22v17H4z M8 21l-1 5M22 21l1 5",
    "hang" to "M4 8h22v14H4z M9 4v4M21 4v4",
    "h-bar" to "M6 3h18v24H6z M19 10v10",
    "h-long" to "M6 3h18v24H6z M19 6v18",
    "h-knob" to "M6 3h18v24H6z M17.5 15a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0",
    "h-gola" to "M6 3h18v24H6z M6 6.5h18",
    "h-push" to "M6 3h18v24H6z M16 12l3 3-3 3",
    "rail" to "M4 7h22M8 7v-2M22 7v-2 M10 9l-4 6h8z M20 9l-4 6h8z M4 22h22",
    "hg-L" to "M6 3h18v24H6z M24 3L6 15l18 12",
    "hg-R" to "M6 3h18v24H6z M6 3l18 12L6 27"
)

@Composable
fun DzGlyph(name: String, color: Color, size: Dp = 26.dp) {
    val d = DZ_GLYPHS[name] ?: return
    Canvas(Modifier.size(size)) {
        val k = this.size.minDimension / 30f
        val p = dzPaths.getOrPut(d) { PathParser().parsePathString(d).toPath() }
        scale(k, k, pivot = Offset.Zero) { drawPath(p, color, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
    }
}

/* ---------------- the slider ---------------- */

/** One tool of the slider: [key], its label's string, icon, a count badge, red (O‘chirish) or the main one (Tayyor), on (a toggle). */
data class DTool(val key: String, val label: String, val icon: String, val badge: Int? = null, val red: Boolean = false, val pri: Boolean = false, val on: Boolean = false)

/** The tool button: icon over a short name, at least 56 dp tall. */
@Composable
private fun ToolBtn(t: DTool, onClick: () -> Unit) {
    val fg = when { t.red -> G.err; t.pri -> Color.White; t.on -> G.cobalt2; else -> G.ink }
    val bg = when { t.pri -> G.cobalt; t.on -> G.cobalt.copy(alpha = .12f); else -> Color.Transparent }
    Box(Modifier.width(70.dp).heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).background(bg)
        .semantics { contentDescription = t.label; selected = t.on }.clickable(role = Role.Button, onClick = onClick).padding(vertical = 6.dp, horizontal = 2.dp),
        contentAlignment = Alignment.TopCenter) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            DzIcon(t.icon, fg, 23.dp, 1.9f)
            BasicText(t.label, style = ui(11.5f, 700, fg, 1.1f).copy(textAlign = TextAlign.Center), maxLines = 2,
                autoSize = TextAutoSize.StepBased(minFontSize = 8.5.sp, maxFontSize = 11.5.sp, stepSize = .5.sp))
        }
        if (t.badge != null) Box(Modifier.align(Alignment.TopEnd).padding(end = 10.dp).size(18.dp).clip(CircleShape).background(if (t.badge > 0) G.err else G.green),
            contentAlignment = Alignment.Center) { Text(if (t.badge > 0) "${t.badge}" else "✓", style = ui(10.5f, 800, Color.White)) }
    }
}

/** A row that scrolls sideways, its cut edge faded while more is past it. */
@Composable
fun FadeRow(key: Any?, modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    val sc = remember(key) { ScrollState(0) }
    Box(modifier) {
        Row(Modifier.horizontalScroll(sc).padding(end = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp), content = content)
        if (sc.value < sc.maxValue) Box(Modifier.align(Alignment.CenterEnd).width(36.dp).height(64.dp)
            .background(Brush.horizontalGradient(listOf(Color.Transparent, G.sheet(.96f)))))
    }
}

/** The slider: the tools for what is selected. */
@Composable
fun ToolSlider(tools: List<DTool>, onPick: (String) -> Unit) {
    FadeRow(tools.joinToString(",") { it.key }, Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp)) {
        tools.forEach { t -> ToolBtn(t) { onPick(t.key) } }
    }
}

/** The panel the slider and the option rows sit in: glass at the canvas's bottom, its place reported for the delete zone. */
@Composable
fun BoxScope.DzcPanel(onBounds: (Rect) -> Unit, onHeight: (Int) -> Unit, content: @Composable () -> Unit) {
    // the toast sits above the slider, not over it
    Column(Modifier.align(Alignment.BottomCenter).then(uz.metrx.app.ui.ux.barSpotModifier()).fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp)
        .clip(RoundedCornerShape(22.dp)).background(G.sheet(.94f)).border(1.dp, G.rim, RoundedCornerShape(22.dp))
        .onGloballyPositioned { c -> onBounds(c.boundsInRoot()); onHeight(c.size.height) }) { content() }
}

/** In place of the slider while a module is carried: drop it here to delete it. */
@Composable
fun DelZone(on: Boolean) {
    Row(Modifier.fillMaxWidth().heightIn(min = 72.dp).background(if (on) G.err else G.errWash).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
        DzIcon("trash", if (on) Color.White else G.err, 24.dp)
        Text(tr("dzc.dropDel"), style = ui(14.5f, 800, if (on) Color.White else G.err), maxLines = 2, textAlign = TextAlign.Center)
    }
}

/** A tool's options in place of the slider: its name and what it applies to (and the scope), then ← and the options. */
@Composable
fun OptRow(title: String, sub: String, onBack: () -> Unit, scope: (@Composable () -> Unit)? = null, key: Any? = title, content: @Composable RowScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = ui(14f, 800), maxLines = 1)
            Text(sub, style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        }
        if (scope != null) Box(Modifier.padding(start = 12.dp, end = 12.dp, top = 6.dp)) { scope() }
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.padding(start = 6.dp).size(48.dp).clip(CircleShape).background(G.ink.copy(alpha = .07f))
                .semantics { contentDescription = "←" }.clickable(role = Role.Button, onClick = onBack), contentAlignment = Alignment.Center) { DzIcon("back", G.ink, 22.dp, 2.2f) }
            FadeRow(key, Modifier.weight(1f).padding(start = 4.dp)) { content() }
        }
    }
}

/** An option chip: a glyph or a swatch over its words, or words alone. */
@Composable
fun OptChip(label: String, on: Boolean, glyph: String? = null, swatch: Color? = null, red: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val fg = when { !enabled -> G.ink3; red -> G.err; on -> G.cobalt2; else -> G.ink }
    Row(Modifier.padding(horizontal = 2.dp).heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp))
        .background(if (on) G.cobalt.copy(alpha = .12f) else G.ink.copy(alpha = .05f))
        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else Color.Transparent, RoundedCornerShape(14.dp))
        .semantics { selected = on }.clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (glyph != null) DzGlyph(glyph, fg, 26.dp)
        if (swatch != null) Box(Modifier.size(24.dp).clip(CircleShape).background(swatch).border(1.dp, G.ink.copy(alpha = .2f), CircleShape))
        Text(label, style = ui(13.5f, 700, fg, 1.15f), maxLines = 2, modifier = Modifier.widthIn(max = 150.dp))
    }
}

/** A − value + stepper among the options. */
@Composable
fun OptStepper(label: String, v: Int, lo: Int, hi: Int, onValue: (Int) -> Unit) {
    Row(Modifier.padding(horizontal = 2.dp).heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .05f)).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, style = ui(13.5f, 700), maxLines = 1)
        listOf(-1, 1).forEach { d ->
            val ok = if (d < 0) v > lo else v < hi
            if (d > 0) Text("$v", style = num(16f, 800), modifier = Modifier.widthIn(min = 22.dp), textAlign = TextAlign.Center)
            Box(Modifier.size(44.dp).clip(CircleShape).background(G.ink.copy(alpha = if (ok) .08f else .03f))
                .semantics { contentDescription = if (d < 0) "−" else "+" }.clickable(enabled = ok, role = Role.Button) { onValue(v + d) }, contentAlignment = Alignment.Center) {
                Text(if (d < 0) "−" else "+", style = ui(20f, 700, if (ok) G.ink else G.ink3))
            }
        }
    }
}

/** A short note among the options. */
@Composable
fun OptNote(text: String) { Text(text, style = ui(12f, 500, G.ink2, 1.3f), maxLines = 3, modifier = Modifier.widthIn(max = 220.dp).padding(horizontal = 8.dp)) }

/** "Faqat shu / Shu qatorga / Butun oshxonaga" over the options. */
@Composable
fun ScopeSeg(items: List<Pair<String, String>>, cur: String, onPick: (String) -> Unit) {
    Row(Modifier.clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        items.forEach { (k, l) ->
            val on = k == cur
            Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(9.dp)).background(if (on) G.solid else Color.Transparent)
                .semantics { selected = on }.clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 10.dp), contentAlignment = Alignment.Center) {
                Text(l, style = ui(12.5f, if (on) 800 else 600, if (on) G.ink else G.ink2), maxLines = 1)
            }
        }
    }
}

/** The front colours of the design (colours, then woods) as swatch chips. */
val FRONT_KEYS: List<Triple<String, String, Boolean>> get() = LOOK_COLOURS.map { Triple(it.key, it.rgb, false) } + LOOK_WOODS.map { Triple(it.key, it.rgb, true) }

/* ---------------- over the drawing ---------------- */

/** The caption over the drawing: what is selected and where, its close; for a front "‹ Module" back to the module. */
@Composable
fun BoxScope.DzcCaption(title: String, sub: String, onClose: (() -> Unit)?, up: String? = null, onUp: (() -> Unit)? = null, multi: Boolean = false) {
    Row(Modifier.align(Alignment.TopCenter).padding(horizontal = 12.dp, vertical = 8.dp).fillMaxWidth().heightIn(min = 44.dp)
        .clip(RoundedCornerShape(14.dp)).background(if (multi) G.cobalt else G.sheet(.92f)).border(1.dp, G.rim, RoundedCornerShape(14.dp)).padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val fg = if (multi) Color.White else G.ink
        if (up != null && onUp != null) Text("‹ $up", style = ui(13f, 700, G.cobalt2), maxLines = 1, modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(role = Role.Button, onClick = onUp).padding(vertical = 8.dp, horizontal = 2.dp))
        Text(title, style = ui(14f, 800, fg), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 230.dp))
        Text(sub, style = ui(12f, 500, if (multi) Color.White.copy(alpha = .85f) else G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        if (onClose != null) Box(Modifier.size(44.dp).clip(CircleShape).semantics { contentDescription = "×" }.clickable(role = Role.Button, onClick = onClose), contentAlignment = Alignment.Center) {
            DzIcon(if (multi) "chk" else "close", fg, 20.dp, 2.2f)
        }
    }
}

/** A small pill at [x], [y] (px, its middle and top): the live width, a height, the absorbing neighbour's change. */
@Composable
fun BoxScope.Bubble(text: String, x: Float, y: Float, live: Boolean = false, amber: Boolean = false, warn: Boolean = false, onClick: (() -> Unit)? = null) {
    val d = LocalDensity.current
    var w by remember { mutableIntStateOf(0) }
    val bg = when { warn -> G.err; amber -> Color(0xFFF59E0B); live -> G.cobalt; else -> G.solid }
    val fg = if (live || amber || warn) Color.White else G.ink
    Row(Modifier.offset { IntOffset((x - w / 2f).roundToInt(), y.roundToInt()) }.onGloballyPositioned { w = it.size.width }
        .heightIn(min = if (onClick != null) 40.dp else 28.dp).clip(RoundedCornerShape(20.dp)).background(bg).border(1.dp, if (live || amber || warn) Color.Transparent else G.cobalt, RoundedCornerShape(20.dp))
        .let { if (onClick != null) it.clickable(role = Role.Button, onClick = onClick) else it }.padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(text, style = num(13.5f, 800, fg), maxLines = 1)
        if (onClick != null && !live) DzIcon("kbd", G.cobalt2, 16.dp, 1.8f)
    }
    @Suppress("UNUSED_VARIABLE") val unused = d
}

/** A check's callout under its module: the problem, a one-tap fix, fold it to its "!" badge. */
@Composable
fun BoxScope.Callout(text: String, fix: String?, x: Float, y: Float, maxW: Float, onFix: () -> Unit, onFold: () -> Unit) {
    val d = LocalDensity.current
    val wPx = with(d) { 240.dp.toPx() }
    val lo = with(d) { 8.dp.toPx() }
    val left = (x - wPx / 2).coerceIn(lo, max(lo, maxW - wPx - lo))
    Column(Modifier.offset { IntOffset(left.roundToInt(), y.roundToInt()) }.width(240.dp).clip(RoundedCornerShape(16.dp)).background(G.solid)
        .border(2.dp, G.err, RoundedCornerShape(16.dp)).padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            DzIcon("warn", G.err, 18.dp)
            Text(text, style = ui(13f, 700, G.err, 1.3f), modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            if (fix != null) Text(fix, style = ui(13.5f, 800, Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(G.err).clickable(role = Role.Button, onClick = onFix).padding(horizontal = 10.dp, vertical = 12.dp))
            else Spacer(Modifier.weight(1f))
            Box(Modifier.size(44.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).semantics { contentDescription = "×" }.clickable(role = Role.Button, onClick = onFold),
                contentAlignment = Alignment.Center) { DzIcon("close", G.ink2, 18.dp) }
        }
    }
}

/** The folded callout: a red "!" at [x], [y]. */
@Composable
fun BoxScope.Badge(x: Float, y: Float, onClick: () -> Unit) {
    Box(Modifier.offset { IntOffset(x.roundToInt(), y.roundToInt()) }.size(30.dp).clip(CircleShape).background(G.err).clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center) { Text("!", style = ui(16f, 900, Color.White)) }
}

/** "120% · sig‘dirish" over the slider while zoomed: a tap fits the drawing again. */
@Composable
fun BoxScope.ZoomPill(z: Float, bottom: Dp, onFit: () -> Unit) {
    Row(Modifier.align(Alignment.BottomStart).padding(start = 14.dp, bottom = bottom).heightIn(min = 40.dp).clip(RoundedCornerShape(20.dp)).background(G.solid)
        .border(1.dp, G.rim, RoundedCornerShape(20.dp)).clickable(role = Role.Button, onClick = onFit).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        DzIcon("fit", G.ink, 16.dp); Text("${(z * 100).roundToInt()}% · " + tr("dzc.fit"), style = ui(12.5f, 700), maxLines = 1)
    }
}

/** The hold's ring filling over [LIFT_MS] at [at] (px). */
@Composable
fun BoxScope.PressRing(at: Offset?) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(at) { a.snapTo(0f); if (at != null) a.animateTo(1f, tween(LIFT_MS.toInt(), easing = LinearEasing)) }
    if (at == null) return
    val col = G.cobalt
    Canvas(Modifier.fillMaxSize()) {
        val r = 26.dp.toPx()
        drawCircle(col.copy(alpha = .15f), r, at)
        drawArc(col, -90f, 360f * a.value, false, Offset(at.x - r, at.y - r), Size(2 * r, 2 * r), style = Stroke(4.dp.toPx(), cap = StrokeCap.Round))
    }
}

/* ---------------- the first-time hint ---------------- */

/** The coach key of the editor's hint: shown once, "Maslahatlarni qayta ko‘rsatish" brings it back. */
const val DZC_HINT = "dzc.teach"

/** About 3 s, skippable: drag the edge → hold to move → pinch, a finger drawn doing each. */
@Composable
fun BoxScope.TeachHint(onDone: () -> Unit) {
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) { t.animateTo(3f, tween(3300, easing = LinearEasing)); kotlinx.coroutines.delay(500); onDone() }
    val step = t.value.toInt().coerceIn(0, 2)
    val k = t.value - step
    val ink = G.ink; val cob = G.cobalt
    Box(Modifier.fillMaxSize().background(Color(0x33000000)).clickable(remember { MutableInteractionSource() }, null) { onDone() }, contentAlignment = Alignment.Center) {
        Column(Modifier.padding(24.dp).widthIn(max = 340.dp).fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(G.solid).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Canvas(Modifier.fillMaxWidth().height(120.dp)) {
                val w = size.width; val h = size.height
                val fy = h * .86f
                drawLine(ink.copy(alpha = .3f), Offset(w * .06f, fy), Offset(w * .94f, fy), 2f)
                val finger = { c: Offset -> drawCircle(Color(0xFFF2C6A0), 13.dp.toPx(), c); drawCircle(ink.copy(alpha = .35f), 13.dp.toPx(), c, style = Stroke(1.5f)) }
                when (step) {
                    0 -> {
                        // the edge dragged left: 600 → 450
                        val x0 = w * .2f; val wid = w * (.46f - .12f * k); val top = h * .28f
                        drawRect(cob.copy(alpha = .15f), Offset(x0, top), Size(wid, fy - top)); drawRect(cob, Offset(x0, top), Size(wid, fy - top), style = Stroke(3f))
                        drawRoundRect(cob, Offset(x0 + wid - 6f, (top + fy) / 2 - 22f), Size(12f, 44f), androidx.compose.ui.geometry.CornerRadius(6f))
                        finger(Offset(x0 + wid + 8f, (top + fy) / 2 + 18f))
                    }
                    1 -> {
                        // held, then carried right; the other slides
                        val top = h * .28f; val bw = w * .26f
                        drawRect(ink.copy(alpha = .12f), Offset(w * .14f + bw * (if (k > .5f) 1.05f else 0f) * 0f, top), Size(bw, fy - top))
                        val lift = if (k < .4f) 0f else 10f
                        val gx = w * .44f + (w * .2f) * ((k - .4f).coerceAtLeast(0f) / .6f)
                        drawRect(cob.copy(alpha = .18f), Offset(gx, top - lift), Size(bw, fy - top)); drawRect(cob, Offset(gx, top - lift), Size(bw, fy - top), style = Stroke(3f))
                        val c = Offset(gx + bw / 2, (top + fy) / 2 - lift)
                        drawArc(cob, -90f, 360f * (k / .4f).coerceAtMost(1f), false, Offset(c.x - 24f, c.y - 24f), Size(48f, 48f), style = Stroke(4f))
                        finger(c)
                    }
                    else -> {
                        // two fingers apart: bigger
                        val sc = 1f + .35f * k
                        val cw = w * .3f * sc; val ch = h * .5f * sc
                        drawRect(cob.copy(alpha = .15f), Offset(w / 2 - cw / 2, h * .48f - ch / 2), Size(cw, ch)); drawRect(cob, Offset(w / 2 - cw / 2, h * .48f - ch / 2), Size(cw, ch), style = Stroke(3f))
                        finger(Offset(w / 2 - w * (.1f + .1f * k), h * .6f)); finger(Offset(w / 2 + w * (.1f + .1f * k), h * .36f))
                    }
                }
            }
            Text(tr(listOf("dzc.teach1", "dzc.teach2", "dzc.teach3")[step]), style = ui(16f, 800, G.ink, 1.25f), textAlign = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                (0..2).forEach { i -> Box(Modifier.size(if (i == step) 18.dp else 7.dp, 7.dp).clip(CircleShape).background(if (i == step) G.cobalt else G.ink.copy(alpha = .15f))) }
            }
            Text(tr("dzc.skip"), style = ui(14.5f, 800, G.cobalt2), modifier = Modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(12.dp))
                .clickable(role = Role.Button, onClick = onDone).padding(horizontal = 16.dp, vertical = 14.dp))
        }
    }
}

/** The first selection of a module shows the hint, once (Profile's "Maslahatlarni qayta ko‘rsatish" resets it). */
fun App.dzcFirstPick(st: DzcState) {
    if (DZC_HINT in settings.coachSeen) return
    settings.markCoach(DZC_HINT)
    st.teach = true
}

/* ---------------- typed sizes ---------------- */

/**
 * The bubble's number sheet (the phone's own number keyboard): [title], the allowed range, "Tayyor" or the laser's next
 * reading; [ok] takes the value (false: out of range, the sheet stays with the reason).
 */
@Composable
fun DzcNumSheet(title: String, cur: Int, lo: Int, hi: Int, note: String? = null, onClose: () -> Unit, ok: (Int) -> Unit) {
    val app = LocalApp.current
    var v by rememberSaveable { mutableStateOf("") }
    val vi = v.toIntOrNull()
    val good = vi != null && vi in lo..hi
    val fr = remember { androidx.compose.ui.focus.FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    fun save() { if (vi == null) { onClose(); return }; if (!good) { app.haptic(Hap.WARN); return }; ok(vi) }
    uz.metrx.app.laser.LaserSink { mm -> v = mm.toString(); app.haptic(Hap.CONFIRM); true }
    GlassSheet(title, onClose, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (busy) "dzc.laserWait" else "dzc.laser"), {
                if (busy) return@GBtn
                if (app.laser.isReal) { busy = true; app.laser.await(onCancel = { busy = false }) { mm -> busy = false; v = mm.toString(); app.haptic(Hap.CONFIRM) } }
                else {
                    // the laser's newest reading not used yet, else the simulator's made-up one near the current size
                    val r = app.settings.readings.lastOrNull { it.used == null && it.src != "manual" }
                    if (r != null) { app.settings.markReadingUsed(r.id, title); v = r.mm.toString(); app.haptic(Hap.CONFIRM) }
                    else scope.launch { busy = true; kotlinx.coroutines.delay(700); v = ((cur + kotlin.random.Random.nextInt(-60, 61)) / 5 * 5).coerceIn(lo, hi).toString(); busy = false; app.haptic(Hap.CONFIRM) }
                }
            }, uz.metrx.app.ui.components.Btn.SECONDARY, icon = "laser", height = 52.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("dzc.done"), ::save, enabled = vi == null || good, height = 52.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1.3f))
        }
    }) {
        GField(title, v, { v = it.filter(Char::isDigit).take(4) }, "$cur", number = true, labelRight = tr("u.mm"),
            error = tr("dzc.range", "a" to lo, "b" to hi), showError = vi != null && !good, imeAction = androidx.compose.ui.text.input.ImeAction.Done, onIme = ::save, focusRequester = fr)
        Text(note ?: tr("dzc.range", "a" to lo, "b" to hi), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/* ---------------- small helpers ---------------- */

/** A toast with "Ortga qaytarish" for a designer change, and the confirm haptic. */
fun App.dzcDone(pid: String, fid: String, text: String) {
    toast = uz.metrx.app.ui.components.ToastMsg(text, uz.metrx.app.ui.components.ToastKind.OK, t("ux.undo"), onAction = { kit.undo(this, pid, fid); haptic(Hap.TICK) })
    haptic(Hap.CONFIRM)
}

/** A designer warning: a red toast and the warning haptic. */
fun App.dzcWarn(text: String) {
    toast = uz.metrx.app.ui.components.ToastMsg(text, uz.metrx.app.ui.components.ToastKind.ERROR)
    haptic(Hap.WARN)
}

/** A drawing's dashed "+" gap: [l]..[r] × [t]..[b] px. */
fun DrawScope.plusGap(l: Float, t: Float, r: Float, b: Float, on: Boolean, hl: Boolean, line: Color, cob: Color) {
    val dash = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(5f, 4f))
    if (hl) drawRect(Color(0x3322C55E), Offset(l, t), Size(r - l, b - t))
    drawRect(if (on) cob else line, Offset(l + 1f, t + 1f), Size(max(0f, r - l - 2f), max(0f, b - t - 2f)), style = Stroke(if (on) 2.2f else 1.2f, pathEffect = dash))
    val w = r - l
    if (w < 12f) return
    val c = Offset((l + r) / 2f, (t + b) / 2f)
    val rad = min(9f, w / 2.4f)
    drawCircle(if (on) cob else Color.White, rad, c)
    drawCircle(if (on) cob else line, rad, c, style = Stroke(1.2f))
    val col = if (on) Color.White else line
    drawLine(col, Offset(c.x - rad * .5f, c.y), Offset(c.x + rad * .5f, c.y), 1.6f, StrokeCap.Round)
    drawLine(col, Offset(c.x, c.y - rad * .5f), Offset(c.x, c.y + rad * .5f), 1.6f, StrokeCap.Round)
}

/** Whether [p] (root px) is within [r] grown by [pad]. */
fun Rect.hits(p: Offset, pad: Float = 0f) = p.x >= left - pad && p.x <= right + pad && p.y >= top - pad && p.y <= bottom + pad

@Suppress("unused") private val keepImports = listOf(abs(0), PointerEventPass.Main, ICONS.size)
