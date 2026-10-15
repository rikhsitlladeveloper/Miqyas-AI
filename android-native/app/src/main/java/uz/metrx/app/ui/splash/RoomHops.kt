package uz.metrx.app.ui.splash

import android.provider.Settings as SysSettings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uz.metrx.app.ui.components.drawLogoMark
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * "Room hops", option B "Line + read hold" from the founder's launch-motion artifact (MxXnmrubuGSLppMi2zwRf1,
 * m8.html + room.js + common.js; chosen 15 Oct 2026), redrawn natively. The laser dot lands in a corner and hops round
 * the room, resting a moment on each landing; each landing snaps a neon wall with its length and adds one word to the
 * line "O‘lchang. Chizing. Hisoblang." (the newest word bright, earlier ones dimmed), the third shows the area; the
 * whole line brightens and the walls glow softly while it is read; then the room folds into the M, the dot lands in
 * the V and swells into blue, and the blue contracts into the logo tile, which docks where the next screen's header
 * logo sits. 3.4 s.
 *
 * Everything is drawn in the artifact's 390 × 844 design stage, scaled to fit the safe area, from one clock t (s).
 *
 * @param dockTo where the 38 dp header tile of the next screen is, in px from the top-left of the screen.
 */
@Composable
fun RoomHops(dockTo: Rect, onDone: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val clock = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val measurer = rememberTextMeasurer()
    val tl = remember { Timeline() }
    val reduced = remember {
        SysSettings.Global.getFloat(context.contentResolver, SysSettings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val finished = remember { booleanArrayOf(false) }
    fun finish() { if (!finished[0]) { finished[0] = true; onDone() } }

    LaunchedEffect(Unit) {
        if (reduced) { clock.snapTo(Timeline.END); delay(600); finish(); return@LaunchedEffect }
        clock.animateTo(Timeline.END, tween((Timeline.END * 1000).toInt(), easing = LinearEasing))
        finish()
    }

    Canvas(
        modifier
            .fillMaxSize()
            .semantics { contentDescription = "METRX" }
            .pointerInput(Unit) { detectTapGestures { scope.launch { clock.stop(); clock.snapTo(Timeline.END); finish() } } }
    ) {
        val dp = density.density
        tl.draw(this, clock.value, dp, dockTo, measurer)
    }
}

private class Timeline {
    companion object {
        // option B's timing (m8.html): landings, hop lengths, the fold; the tail after the fold always takes 1.30 s
        const val LA = .22f; const val LB = .58f; const val LD = 1.14f; const val LE = 1.68f
        const val HB = .22f; const val HD = .24f; const val HE = .22f
        const val F = 2.10f; const val BRIGHT = 1.98f
        const val WIPE = F + .34f; const val CN = WIPE + .30f; const val DOCK = CN + .46f
        const val END = DOCK + .2f
    }

    // ---- geometry of the artifact, in stage px ----
    private val S = 3.42f
    private val A0 = Offset(80f, 480f); private val B0 = Offset(80f, 330f); private val C0 = Offset(195f, 330f)
    private val D0 = Offset(310f, 330f); private val E0 = Offset(310f, 480f)
    /** The M of the logo, mapped from the 88 px logo box (centre 44, 45.375) onto the stage at scale S around (195, 405). */
    private fun logoToStage(x: Float, y: Float) = Offset(195f + (x - 44f) * S, 405f + (y - 45.375f) * S)
    private val u = 1.375f
    private val A1 = logoToStage(15 * u, 47 * u); private val B1 = logoToStage(15 * u, 19 * u); private val C1 = logoToStage(32 * u, 38 * u)
    private val D1 = logoToStage(49 * u, 19 * u); private val E1 = logoToStage(49 * u, 47 * u)
    private val CST = C1                                    // where the V bottom sits

    private val neon = listOf(0f to Color(0xFF5B7BFF), .55f to Color(0xFF3FD8F2), 1f to Color(0xFFB07CFF))
    private val wallBrush = Brush.linearGradient(*neon.toTypedArray(), start = Offset(A0.x, B0.y), end = E0)

    // ---- the laser dot: x, y = contact point; sx, sy = squash and stretch about the contact point ----
    private val dotX = Track(80f); private val dotY = Track(220f); private val dotO = Track(0f)
    private val dotSX = Track(1f); private val dotSY = Track(1f)

    private fun land(t: Float, wide: Boolean = false) {
        dotSX.to(t, .05f, if (wide) 1.7f else 1.45f, Ease.p1Out); dotSY.to(t, .05f, if (wide) .5f else .62f, Ease.p1Out)
        dotSX.to(t + .05f, .1f, 1f, Ease.backOut(3f)); dotSY.to(t + .05f, .1f, 1f, Ease.backOut(3f))
    }
    private fun hop(t: Float, to: Offset, apex: Float, dur: Float) {
        dotSX.to(t - .06f, .06f, 1.25f, Ease.p1Out); dotSY.to(t - .06f, .06f, .72f, Ease.p1Out)
        dotX.to(t, dur, to.x, Ease.p1InOut)
        dotY.to(t, dur * .45f, apex, Ease.p2Out); dotY.to(t + dur * .45f, dur * .55f, to.y, Ease.p2In)
        dotSX.to(t, dur * .25f, .8f, Ease.p1Out); dotSY.to(t, dur * .25f, 1.3f, Ease.p1Out)
        dotSX.to(t + dur * .25f, dur * .25f, 1f, Ease.sineInOut); dotSY.to(t + dur * .25f, dur * .25f, 1f, Ease.sineInOut)
        dotSX.to(t + dur * .62f, dur * .3f, .82f, Ease.p1In); dotSY.to(t + dur * .62f, dur * .3f, 1.25f, Ease.p1In)
    }

    // ---- walls: how much of the room outline is drawn, then the fold into the M ----
    private val wallDraw = Track(0f); private val wallOn = Track(0f); private val fold = Track(0f); private val planO = Track(1f)
    private val floorA = Track(0f); private val floorB = Track(0f); private val floorO = Track(0f)
    private fun snap(to: Float, t: Float) { wallOn.set(t, 1f); wallDraw.to(t, .12f, to, Ease.p3Out) }

    private val dotScale = mapOf('A' to Track(0f), 'B' to Track(0f), 'C' to Track(0f), 'D' to Track(0f), 'E' to Track(0f))
    private fun mark(k: Char, t: Float) { dotScale.getValue(k).to(t, .18f, 1f, Ease.backOut(3f)) }

    private val rings = listOf(A0 to LA, B0 to LB, D0 to LD, E0 to LE)
    /** The walls' middle glow layer (.wl.g1), which breathes during the read hold. */
    private val glowG1 = Track(.38f)

    // ---- dimension lines, labels, area ----
    private val dmL = Track(0f); private val dmT = Track(0f); private val dtL = Track(0f); private val dtT = Track(0f)
    private val dimsO = Track(1f)
    private val areaO = Track(0f); private val areaS = Track(.6f)

    // ---- the tagline: one line built word by word (room.css #tagline) ----
    private val words = listOf("O‘lchang.", "Chizing.", "Hisoblang.")
    private val wordO = List(3) { Track(0f) }; private val wordY = List(3) { Track(0f) }
    private val taglineO = Track(1f)
    private fun wordIn(i: Int, t: Float) {
        wordO[i].fromTo(t, .18f, 0f, 1f, Ease.p3Out); wordY[i].fromTo(t, .18f, 8f, 0f, Ease.p3Out)
        for (j in 0 until i) wordO[j].to(t, .2f, .6f, Ease.p1Out)        // the newest word brightest
    }

    // ---- the blue: wipe, logo, tile, lockup, dock ----
    private val flipSolid = Track(0f); private val logoO = Track(0f)
    private val logoK = Track(S); private val logoY = Track(-17f - 1.375f * S)
    private val tileO = Track(0f); private val tileK = Track(1f); private val shadowO = Track(0f); private val shadowY = Track(-4f)
    private val light = Track(0f)                          // 0: blueprint, 1: the light paper and aurora
    private val lockupX = Track(1f)                         // fraction of the centring shift still applied
    private val dock = Track(0f)

    init {
        // the laser dot falls into the first corner
        val fall = .20f
        dotO.to(maxOf(0f, LA - fall - .02f), .06f, 1f, Ease.none)
        dotSX.to(LA - fall, fall * .9f, .8f, Ease.p1In); dotSY.to(LA - fall, fall * .9f, 1.3f, Ease.p1In)
        dotY.to(LA - fall, fall, 486f, Ease.p2In); land(LA); mark('A', LA)

        // three hops: each landing snaps a wall and adds a word
        hop(LB - HB, Offset(80f, 336f), 290f, HB); land(LB)                        // left wall
        snap(150f / 530f, LB); mark('B', LB); wordIn(0, LB)
        dmL.to(LB + .10f, .2f, 1f, Ease.p3Out); dtL.to(LB + .12f, .14f, 1f, Ease.none)

        hop(LD - HD, Offset(310f, 336f), 262f, HD); land(LD)                       // top wall
        snap(380f / 530f, LD); mark('D', LD); wordIn(1, LD)
        dmT.to(LD + .10f, .2f, 1f, Ease.p3Out); dtT.to(LD + .12f, .14f, 1f, Ease.none)

        hop(LE - HE, Offset(310f, 486f), 300f, HE); land(LE)                       // right wall, floor closes, area
        snap(1f, LE); mark('E', LE); wordIn(2, LE)
        floorO.set(LE + .02f, 1f); floorB.to(LE + .02f, .12f, 1f, Ease.p2Out)
        areaO.fromTo(LE + .08f, .2f, 0f, 1f, Ease.backOut(2.2f)); areaS.fromTo(LE + .08f, .2f, .6f, 1f, Ease.backOut(2.2f))

        // the read hold: the whole line back to full brightness, the walls breathe once
        wordO.forEach { it.to(BRIGHT, .25f, 1f, Ease.p1InOut) }
        val g = (F - LE - .14f) / 2f
        glowG1.to(LE + .12f, g, .62f, Ease.sineInOut); glowG1.to(LE + .12f + g, g, .38f, Ease.sineInOut)

        // the room folds into the M; the dot hops into the V
        dimsO.to(F, .1f, 0f, Ease.p1In)
        floorA.to(F, .12f, .5f, Ease.p2In); floorB.to(F, .12f, .5f, Ease.p2In); floorO.set(F + .12f, 0f)
        fold.to(F, .32f, 1f, Ease.p3InOut)
        dotScale.getValue('C').to(F, .14f, 1f, Ease.expoOut)
        dotScale.getValue('A').to(F, .32f, 0f, Ease.p2In); dotScale.getValue('E').to(F, .32f, 0f, Ease.p2In)
        hop(F + .02f, Offset(CST.x, CST.y + 6f), 360f, .30f); land(F + .32f, true)

        // the dot swells into blue and covers everything; the drawing becomes the solid M
        dotO.set(WIPE, 0f)
        flipSolid.set(WIPE + .28f, 1f)
        logoO.to(WIPE + .19f, .08f, 1f, Ease.none); planO.to(WIPE + .19f, .08f, 0f, Ease.none)
        taglineO.set(WIPE + .24f, 0f)                                                // already under the blue

        // the blue contracts into the tile; layers swap while the screen is covered
        tileO.set(CN, 1f); light.set(CN, 1f); flipSolid.set(CN, 0f)
        tileK.to(CN, .22f, .95f, Ease.expoInOut); tileK.to(CN + .22f, .14f, 1f, Ease.backOut(2.5f))
        logoK.to(CN, .22f, 1f, Ease.expoInOut); logoY.to(CN, .22f, 0f, Ease.expoInOut)
        shadowO.fromTo(CN + .14f, .2f, 0f, 1f, Ease.p2Out); shadowY.fromTo(CN + .14f, .2f, -4f, 0f, Ease.p2Out)
        lockupX.to(CN + .14f, .3f, 0f, Ease.p3Out)
        dock.to(DOCK, .2f, 1f, Ease.p3Out)
    }

    private val roomPath = Path()
    private val measure = PathMeasure()
    private val seg = Path()

    fun draw(ds: DrawScope, t: Float, dp: Float, dockTo: Rect, tm: TextMeasurer) = with(ds) {
        val W = size.width; val H = size.height
        // fit the 390 × 844 stage, like layout() in common.js (status and navigation bars are inside the canvas)
        val s = min(min(W / dp / 390f, H / dp / 844f), 1.25f) * dp
        val sx = (W - 390f * s) / 2f; val sy = (H - 844f * s) / 2f
        val vb = Rect(-sx / s, -sy / s, (W - sx) / s, (H - sy) / s)
        val lit = light(t) >= 1f

        // ---- background ----
        if (!lit) {
            drawRect(G.blueprint)
            withTransform({ scale(1f, (H * .5f) / (W * .7f), pivot = Offset(W * .5f, H * .46f)) }) {
                drawCircle(Brush.radialGradient(0f to Color(0x613550E0), .7f to Color(0x003550E0), center = Offset(W * .5f, H * .46f), radius = W * .7f), W * .7f, Offset(W * .5f, H * .46f))
            }
            grid(Color(0x1C7A92FF), dp)
        } else {
            drawRect(G.paper)
            aurora(dp)
            grid(Color(0x0F3550E0), dp)
        }

        translate(sx, sy) { scale(s, s, pivot = Offset.Zero) {
            if (!lit) {
                if (planO(t) > 0f) plan(t, planO(t))
                dims(t, tm)
                tagline(t, tm)
                rings(t)
                logoOnBlue(t)
                dot(t)
                wipe(t, vb)
            } else {
                lockup(t, vb, s, sx, sy, dockTo, tm)
            }
        } }
    }

    private fun DrawScope.grid(c: Color, dp: Float) {
        val step = 23f * dp
        var x = 0f; while (x < size.width) { drawRect(c, Offset(x, 0f), Size(dp, size.height)); x += step }
        var y = 0f; while (y < size.height) { drawRect(c, Offset(0f, y), Size(size.width, dp)); y += step }
    }

    private fun DrawScope.aurora(dp: Float) {
        // the light end frame of the artifact (#aur in common.css, inset -8%)
        val w = size.width * 1.16f; val h = size.height * 1.16f; val ox = -size.width * .08f; val oy = -size.height * .08f
        fun glow(rx: Float, ry: Float, cx: Float, cy: Float, c: Long) {
            val center = Offset(ox + w * cx, oy + h * cy)
            withTransform({ scale(1f, (h * ry) / (w * rx), pivot = center) }) {
                drawCircle(Brush.radialGradient(0f to Color(c), .7f to Color(c).copy(alpha = 0f), center = center, radius = w * rx), w * rx, center)
            }
        }
        glow(.58f, .40f, .06f, .04f, 0x665B7BFF); glow(.52f, .36f, 1.04f, .40f, 0x4DB07CFF)
        glow(.58f, .38f, -.02f, .82f, 0x4D3FD8F2); glow(.56f, .38f, 1.02f, 1.02f, 0x66FFB58A)
    }

    private fun lerp(a: Offset, b: Offset, k: Float) = Offset(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k)

    private fun DrawScope.plan(t: Float, alpha: Float) {
        val k = fold(t)
        val pts = listOf(lerp(A0, A1, k), lerp(B0, B1, k), lerp(C0, C1, k), lerp(D0, D1, k), lerp(E0, E1, k))
        roomPath.reset(); roomPath.moveTo(pts[0].x, pts[0].y); for (i in 1 until pts.size) roomPath.lineTo(pts[i].x, pts[i].y)
        val drawn = if (k > 0f) 1f else wallDraw(t)
        if (wallOn(t) > 0f && drawn > 0f) {
            measure.setPath(roomPath, false); seg.reset()
            measure.getSegment(0f, measure.length * drawn, seg, true)
            neonStroke(seg, alpha, glowG1(t))
        }
        if (floorO(t) > 0f) {
            val fa = floorA(t); val fb = floorB(t)
            if (fb > fa) {
                val fp = Path().apply { moveTo(E0.x, E0.y); lineTo(A0.x, A0.y) }
                measure.setPath(fp, false); seg.reset(); measure.getSegment(measure.length * fa, measure.length * fb, seg, true)
                drawPath(seg, wallBrush, alpha = .38f * alpha, style = Stroke(6f, cap = StrokeCap.Round))
                drawPath(seg, Color(0xFFECF3FF), alpha = alpha, style = Stroke(1.8f, cap = StrokeCap.Round))
            }
        }
        // corner dots
        val at = mapOf('A' to lerp(A0, A1, k), 'B' to lerp(B0, B1, k), 'C' to lerp(C0, C1, k), 'D' to lerp(D0, D1, k), 'E' to lerp(E0, E1, k))
        for ((key, p) in at) {
            val sc = dotScale.getValue(key)(t); if (sc <= 0f) continue
            scale(sc, sc, pivot = p) {
                drawCircle(Brush.radialGradient(0f to Color.White, .3f to Color(0xE6A9ECFF), 1f to Color(0x003FD8F2), center = p, radius = 12f), 12f, p, alpha = .7f * alpha)
                drawCircle(Color.White, 3f, p, alpha = alpha)
            }
        }
    }

    private fun DrawScope.neonStroke(p: Path, alpha: Float, g1: Float) {
        drawPath(p, wallBrush, alpha = .14f * alpha, style = Stroke(13f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(p, wallBrush, alpha = g1 * alpha, style = Stroke(6f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(p, Color(0xFFECF3FF), alpha = alpha, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

    private val dimColor = Color(0x9EBECDFF)
    private val labelStyle = TextStyle(fontFamily = Jakarta, fontWeight = FontWeight.Bold, fontSize = 13.sp, letterSpacing = .02.em, color = Color(0xFFC9D4FF))

    private fun DrawScope.dims(t: Float, tm: TextMeasurer) {
        val o = dimsO(t); if (o <= 0f) return
        val st = Stroke(1f)
        val l = dmL(t)
        if (l > 0f) { val mid = 405f; val h = 75f * l; drawLine(dimColor, Offset(62f, mid - h), Offset(62f, mid + h), 1f, alpha = o) }
        if (dtL(t) > 0f) {
            val a = dtL(t) * o
            drawPath(Path().apply { moveTo(76f, 330f); lineTo(56f, 330f); moveTo(76f, 480f); lineTo(56f, 480f); moveTo(58f, 334f); lineTo(66f, 326f); moveTo(58f, 484f); lineTo(66f, 476f) }, dimColor, a, st)
            label("3,60 m", Offset(43f, 405f), -90f, a, tm)
        }
        val tt = dmT(t)
        if (tt > 0f) { val mid = 195f; val w = 115f * tt; drawLine(dimColor, Offset(mid - w, 312f), Offset(mid + w, 312f), 1f, alpha = o) }
        if (dtT(t) > 0f) {
            val a = dtT(t) * o
            drawPath(Path().apply { moveTo(80f, 326f); lineTo(80f, 306f); moveTo(310f, 326f); lineTo(310f, 306f); moveTo(76f, 316f); lineTo(84f, 308f); moveTo(306f, 316f); lineTo(314f, 308f) }, dimColor, a, st)
            label("5,20 m", Offset(195f, 296f), 0f, a, tm)
        }
        val ao = areaO(t).coerceIn(0f, 1f) * o
        if (ao > 0f) {
            val txt = buildAnnotatedString {
                append("18,72")
                withStyle(SpanStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium, color = Color(0xFFC9D4FF))) { append(" m²") }
            }
            val r = tm.measure(txt, density = UNIT, style = TextStyle(fontFamily = Jakarta, fontWeight = FontWeight.Bold, fontSize = 26.sp, color = Color.White, shadow = Shadow(Color(0x733FD8F2), blurRadius = 16f)))
            val sc = areaS(t)
            scale(sc, sc, pivot = Offset(195f, 404f)) { drawText(r, topLeft = Offset(195f - r.size.width / 2f, 404f - r.size.height / 2f), alpha = ao) }
        }
    }

    /** Text is measured at density 1, so its sizes are stage px like everything else drawn inside the stage transform. */
    private val UNIT = Density(1f, 1f)

    private fun DrawScope.label(text: String, center: Offset, rot: Float, alpha: Float, tm: TextMeasurer) {
        val r = tm.measure(text, labelStyle, density = UNIT)
        rotate(rot, center) { drawText(r, topLeft = Offset(center.x - r.size.width / 2f, center.y - r.size.height / 2f), alpha = alpha) }
    }

    private val tagStyle = TextStyle(fontFamily = Jakarta, fontWeight = FontWeight.Bold, fontSize = 22.sp, color = Color(0xFFF2F6FF), shadow = Shadow(Color(0x593FD8F2), blurRadius = 12f))
    private var tagWords: List<TextLayoutResult>? = null
    private var tagSpace = 0f

    /** The line under the room: centred on y 536 (its 28 px line box starts at 522), whole words with a space between. */
    private fun DrawScope.tagline(t: Float, tm: TextMeasurer) {
        val lo = taglineO(t); if (lo <= 0f) return
        val ws = tagWords ?: words.map { tm.measure(it, tagStyle, density = UNIT) }.also {
            tagWords = it
            tagSpace = tm.measure("a a", tagStyle, density = UNIT).size.width - 2f * tm.measure("a", tagStyle, density = UNIT).size.width
        }
        val total = ws.sumOf { it.size.width }.toFloat() + tagSpace * (ws.size - 1)
        var x = 195f - total / 2f
        ws.forEachIndexed { i, r ->
            val o = (wordO[i](t) * lo).coerceIn(0f, 1f)
            if (o > 0f) drawText(r, topLeft = Offset(x, 536f - r.size.height / 2f + wordY[i](t)), alpha = o)
            x += r.size.width + tagSpace
        }
    }

    private fun DrawScope.rings(t: Float) {
        for ((p, at) in rings) {
            if (t < at || t > at + .42f) continue
            val k = Ease.p2Out((t - at) / .42f)
            val o = .9f * (1 - k); val sc = .3f + (2.4f - .3f) * k
            drawCircle(Color(0xD978DCFF), 13f * sc, p, alpha = o, style = Stroke(1.5f * sc))
        }
    }

    private fun DrawScope.dot(t: Float) {
        val o = dotO(t); if (o <= 0f) return
        val p = Offset(dotX(t), dotY(t))
        withTransform({ scale(dotSX(t), dotSY(t), pivot = p) }) {
            val c = Offset(p.x, p.y - 6f)
            drawCircle(Brush.radialGradient(0f to Color(0x735B7BFF), 1f to Color(0x005B7BFF), center = c, radius = 30f), 30f, c, alpha = o)
            drawCircle(Brush.radialGradient(0f to Color(0xBF3FD8F2), 1f to Color(0x003FD8F2), center = c, radius = 14f), 14f, c, alpha = o)
            drawCircle(Color.White, 6f, c, alpha = o)
        }
    }

    private fun DrawScope.wipe(t: Float, vb: Rect) {
        if (flipSolid(t) >= 1f) { drawRect(G.cobalt, Offset(vb.left, vb.top), Size(vb.width, vb.height)); return }
        if (t < WIPE) return
        val far = listOf(Offset(vb.left, vb.top), Offset(vb.right, vb.top), Offset(vb.left, vb.bottom), Offset(vb.right, vb.bottom))
            .maxOf { hypot(it.x - CST.x, it.y - CST.y) }
        val k = Ease.p2In(((t - WIPE) / .28f).coerceIn(0f, 1f))
        val scale = 1f + ((2 * far) / 12f + 2f - 1f) * k
        drawCircle(G.cobalt, 6f * scale, CST)
    }

    /** The white M on the blue, at hero scale (it fades in once the circle has covered the M). */
    private fun DrawScope.logoOnBlue(t: Float) {
        val o = logoO(t); if (o <= 0f) return
        drawLogo(Offset(195f, 422f + logoY(t)), 88f * logoK(t), o, G.cobalt)
    }

    private fun DrawScope.drawLogo(center: Offset, box: Float, alpha: Float, tile: Color) {
        // the 64-unit mark inside the 88 px box: the artifact draws it with viewBox 0 0 64 64 at 88 px
        val tl = Offset(center.x - box / 2f, center.y - box / 2f)
        if (alpha < 1f) {
            drawContext.canvas.saveLayer(Rect(tl, Size(box, box)).inflate(box * .2f), androidx.compose.ui.graphics.Paint().apply { this.alpha = alpha })
            drawLogoMark(tile, box, tl); drawContext.canvas.restore()
        } else drawLogoMark(tile, box, tl)
    }

    // ---- the light end frame: shadow, tile, logo, wordmark; then everything docks into the header ----
    private val wordStyle = TextStyle(fontFamily = Jakarta, fontWeight = FontWeight.Bold, fontSize = 34.737.sp, letterSpacing = .32.em, color = G.ink)
    private var wordLetters: List<TextLayoutResult>? = null

    private fun DrawScope.lockup(t: Float, vb: Rect, s: Float, sx: Float, sy: Float, dockTo: Rect, tm: TextMeasurer) {
        val letters = wordLetters ?: "METRX".map { tm.measure(it.toString(), wordStyle, density = UNIT) }.also { wordLetters = it }
        // the last letter has no trailing spacing (common.css: #word span:last-child{letter-spacing:0})
        val ls = 34.737f * .32f
        val ww = letters.sumOf { it.size.width }.toFloat() + ls * (letters.size - 1)   // single letters are measured without their spacing
        val T = 88f; val gap = 10f * (88f / 38f)
        val shift = (gap + ww) / 2f
        val L = 195f - (T + gap + ww) / 2f
        val lx = L + shift * lockupX(t)
        val top = 378f

        // dock: move the whole lockup so the tile lands on the header tile (38 dp)
        val d = dock(t)
        val targetTL = Offset((dockTo.left - sx) / s, (dockTo.top - sy) / s)
        val k = 1f + ((dockTo.width / s) / T - 1f) * d
        val ox = lx + (targetTL.x - lx) * d; val oy = top + (targetTL.y - top) * d

        withTransform({ translate(ox, oy); scale(k, k, pivot = Offset.Zero) }) {
            // shadow under the tile
            val so = shadowO(t)
            if (so > 0f) drawIntoCanvas { cv ->
                val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                    color = android.graphics.Color.argb((92 * so).toInt(), 53, 80, 224)
                    maskFilter = android.graphics.BlurMaskFilter(15f, android.graphics.BlurMaskFilter.Blur.NORMAL)
                }
                cv.nativeCanvas.drawRoundRect(8f, 8f + 18f + shadowY(t), 80f, 80f + 18f + shadowY(t), 20f, 20f, paint)
            }
            // tile: starts covering the screen, contracts to 88 px with a small overshoot
            val tk = tileK(t)
            val cover = 2f * max(max(195f - vb.left, vb.right - 195f), max(422f - vb.top, vb.bottom - 422f)) / 88f * 1.03f
            val tileScale = if (t < CN) cover else {
                // the contraction runs from the cover scale towards .95, then settles at 1
                val p = ((t - CN) / .22f).coerceIn(0f, 1f)
                if (t < CN + .22f) cover + (.95f - cover) * Ease.expoInOut(p) else tk
            }
            val c = Offset(44f, 44f)
            scale(tileScale, tileScale, pivot = c) {
                drawRoundRect(G.cobalt, Offset.Zero, Size(88f, 88f), CornerRadius(22f))
            }
            drawLogo(Offset(44f, 44f + logoY(t)), 88f * logoK(t), 1f, G.cobalt)
            // wordmark letters pop in one after another
            var x = T + gap
            letters.forEachIndexed { i, r ->
                val st = CN + .16f + i * .03f
                val p = ((t - st) / .24f).coerceIn(0f, 1f)
                if (t >= st) {
                    val e = Ease.backOut(2.2f)(p)
                    val sc = .4f + .6f * e
                    val bottom = Offset(x + r.size.width / 2f, 42.77f + r.size.height / 2f)   // the word's line box: top 25.4, 34.737 tall
                    scale(sc, sc, pivot = bottom) { drawText(r, topLeft = Offset(x, 42.77f - r.size.height / 2f + 18f * (1 - e)), alpha = e.coerceIn(0f, 1f)) }
                }
                x += r.size.width + ls
            }
        }
    }
}
