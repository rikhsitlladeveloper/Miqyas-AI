package uz.metrx.app.ui.rooms

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.Theme
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * The room-shape flow's plan picture (design/room-shapes/mockup.html, planSvg, opSvg, shapeThumb, heightSvg), drawn with
 * a Compose Canvas: the room to scale, the wall being asked glowing with its "?" pill, done walls with their size,
 * derived walls dashed and "avtomat", the openings and the start corner's dot. Everything is laid out in the mockup's
 * own units (the picture is [VB] units wide) and scaled to the canvas.
 */

/** The picture's width in the mockup's units: strokes, pills and text keep the mockup's sizes. */
private const val VB = 330f

/** A point of the plan in mm, before the mirror and the turns. */
data class P2(val x: Double, val y: Double)

/** One wall of the plan: [asked] the index of the asked value it comes from (null: worked out), its length and ends. */
data class PlanEdge(val asked: Int?, val len: Double, val bad: Boolean, val a: P2, val b: P2)

/** A size that is not a wall (the bay's width and depth): [asked] its value's index, [kind] "w" or "d". */
data class PlanDim(val a: P2, val b: P2, val asked: Int, val kind: String, val value: Double = 0.0)

/** What the picture draws: the corners, the walls, the bay's sizes, and an open sketch's closing gap. */
data class PlanModel(val pts: List<P2>, val edges: List<PlanEdge>, val dims: List<PlanDim> = emptyList(), val gap: Pair<P2, P2>? = null, val gapLen: Double = 0.0)

/** An opening or a site point on the plan: [kind] door, window, water, sewer or gas; [dist] from the wall's start corner; [w] its width. */
data class PlanOp(val kind: String, val wall: Int, val dist: Int, val w: Int = 0)

/** How the picture is drawn, as the mockup's planSvg options. */
data class PlanLook(
    /** The asked value being typed (its wall glows), and the values done so far. */
    val cur: Int? = null,
    val done: Set<Int> = emptySet(),
    /** What is being typed into [cur], already in words ("3 400"); null shows "?". */
    val liveTxt: String? = null,
    /** The summary and the openings step: every wall with its size. */
    val final: Boolean = false,
    /** An opening's steps: its wall picked (glowing with letter and size), and the start corner's dot. */
    val sel: Int? = null,
    val corner: Int? = null,
    /** "Which wall?": the walls with their letters, a tap picks one. */
    val pick: Boolean = false,
    val nolab: Boolean = false,
    val ops: List<PlanOp> = emptyList(),
    val preview: PlanOp? = null,
    /** The free sketch's diagonal from corner 0 to corner [diagK]: [diagCur] being asked, [diagTxt] its pill. */
    val diagK: Int? = null,
    val diagCur: Boolean = false,
    val diagTxt: String? = null,
    /** The bay's sizes: their values in words by asked index, and the words before they are typed ("eni", "chuq."). */
    val dimTxt: Map<Int, String> = emptyMap(),
    val dimWords: Pair<String, String> = "eni" to "chuq.",
    /** A length in the flow's unit and words ("3 400" mm, "3,4" m). */
    val fmt: (Double) -> String = ::fmtMm,
    val pad: Float = 28f,
    /** Room kept free on the right (the picture's Ko‘zgu / Burish buttons). */
    val rp: Float = 0f
)

/** The plan point after the mirror (x flips) and [rot] quarter turns, each (x, y) → (−y, x). */
fun tf(p: P2, mir: Boolean, rot: Int): P2 {
    var x = if (mir) -p.x else p.x
    var y = p.y
    repeat(((rot % 4) + 4) % 4) { val t = x; x = -y; y = t }
    return P2(x, y)
}

/** Fits the plan into a [w] × [h] box, as the mockup's fitter: the scale (units per mm) and the mapping. */
private class Fit(m: PlanModel, mir: Boolean, rot: Int, w: Float, h: Float, pad: Float, rp: Float) {
    val s: Float
    private val ox: Float
    private val oy: Float
    private val mir0 = mir
    private val rot0 = rot
    init {
        val all = ArrayList<P2>()
        all += m.pts; m.dims.forEach { all += it.a; all += it.b }; m.gap?.let { all += it.first }
        val q = all.map { tf(it, mir, rot) }
        val mnx = q.minOfOrNull { it.x } ?: 0.0; val mxx = q.maxOfOrNull { it.x } ?: 1.0
        val mny = q.minOfOrNull { it.y } ?: 0.0; val mxy = q.maxOfOrNull { it.y } ?: 1.0
        val bw = max(mxx - mnx, 1.0); val bh = max(mxy - mny, 1.0)
        s = min((w - 2 * pad - rp) / bw, (h - 2 * pad) / bh).toFloat()
        ox = ((w - rp - bw * s) / 2 - mnx * s).toFloat()
        oy = ((h - bh * s) / 2 - mny * s).toFloat()
    }
    fun m(p: P2): Offset { val q = tf(p, mir0, rot0); return Offset(ox + q.x.toFloat() * s, oy + q.y.toFloat() * s) }
}

/** Twice the signed area: which side of a wall is inside. */
private fun area2(v: List<Offset>): Float { var a = 0f; for (i in v.indices) { val p = v[i]; val q = v[(i + 1) % v.size]; a += p.x * q.y - q.x * p.y }; return a }

/** "3 400", the mockup's fmt. */
fun fmtMm(v: Double): String = Math.round(abs(v)).toString().reversed().chunked(3).joinToString("\u00A0").reversed()
fun fmtSigned(v: Double): String = (if (v < 0) "−" else "") + fmtMm(v)

/** The plan's colours, as the mockup's tokens. */
private object PC {
    val paper get() = if (Theme.dark) Color(0xFF161C30) else Color(0xFFF7F8FC)
    val room get() = G.cobalt.copy(alpha = if (Theme.dark) .2f else .11f)
    val blue get() = G.cobalt
    val red get() = if (Theme.dark) Color(0xFFF87171) else Color(0xFFDC2626)
    val win = Color(0xFF38BDF8)
    fun opC(k: String) = when (k) { "water" -> Color(0xFF0EA5E9); "sewer" -> Color(0xFF78716C); else -> Color(0xFFF59E0B) }
    fun opL(k: String) = when (k) { "water" -> "S"; "sewer" -> "K"; else -> "G" }
}

/** A wall's state in the picture, as the mockup's eState. */
private fun eState(e: PlanEdge, i: Int, o: PlanLook): String = when {
    e.bad -> "bad"
    o.pick -> "pick"
    o.sel != null -> if (i == o.sel) "cur" else if (e.asked == null) "auto" else "done"
    o.final -> if (e.asked == null) "auto" else "done"
    e.asked == null -> "auto"
    o.cur == e.asked -> "cur"
    e.asked in o.done -> "done"
    else -> "todo"
}

/**
 * The plan picture. [letters] names the walls (A, B, C…); [auto] is the "avtomat" word; [onPick] gets a wall's index
 * when [PlanLook.pick] is on and a wall is tapped.
 */
@Composable
fun PlanPic(m: PlanModel, mir: Boolean, rot: Int, look: PlanLook, letters: List<String>, auto: String, gapWord: String, modifier: Modifier, onPick: ((Int) -> Unit)? = null) {
    val tm = rememberTextMeasurer()
    val glow by rememberInfiniteTransition(label = "glow").animateFloat(.22f, .42f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "glowA")
    val pickNow by rememberUpdatedState(onPick)
    val tap = if (look.pick && onPick != null) Modifier.pointerInput(m, mir, rot) {
        detectTapGestures { t ->
            val k = size.width / VB
            val H = size.height / k
            val f = Fit(m, mir, rot, VB, H, look.pad, look.rp)
            val p = Offset(t.x / k, t.y / k)
            // the nearest wall within about a finger's width
            var best = -1; var bd = Float.MAX_VALUE
            m.edges.forEachIndexed { i, e -> val d = segDist(p, f.m(e.a), f.m(e.b)); if (d < bd) { bd = d; best = i } }
            if (best >= 0 && bd < 30f) pickNow?.invoke(best)
        }
    } else Modifier
    Canvas(modifier.then(tap)) {
        val k = size.width / VB
        val H = size.height / k
        withTransform({ scale(k, k, pivot = Offset.Zero) }) {
            drawPlan(m, mir, rot, look, letters, auto, gapWord, tm, H, glow)
        }
    }
}

private fun segDist(p: Offset, a: Offset, b: Offset): Float {
    val d = b - a; val l = d.x * d.x + d.y * d.y
    if (l < 1e-6f) return (p - a).getDistance()
    val t = (((p.x - a.x) * d.x + (p.y - a.y) * d.y) / l).coerceIn(0f, 1f)
    return hypot(p.x - a.x - t * d.x, p.y - a.y - t * d.y)
}

private fun DrawScope.line(a: Offset, b: Offset, c: Color, w: Float, dash: FloatArray? = null, alpha: Float = 1f) =
    drawLine(c.copy(alpha = c.alpha * alpha), a, b, w, StrokeCap.Round, if (dash != null) PathEffect.dashPathEffect(dash) else null)

/** A pill waiting to be drawn: where, which way is out from its wall, its words and state. */
private class PillAt(val x: Float, val y: Float, val nx: Float, val ny: Float, val t: String, val st: String)

private fun pillW(t: String, st: String) = max(24f, t.length * (if (st == "auto") 5.6f else 6.6f) + 14f)

/** The box a pill takes, as [pill] clamps it inside the picture. */
private fun pillRect(x0: Float, y0: Float, t: String, st: String, W: Float, H: Float): androidx.compose.ui.geometry.Rect {
    val w = pillW(t, st)
    val x = x0.coerceIn(w / 2 + 2, max(w / 2 + 2, W - w / 2 - 2)); val y = y0.coerceIn(12f, max(12f, H - 12f))
    return androidx.compose.ui.geometry.Rect(x - w / 2, y - 10f, x + w / 2, y + 10f)
}

/** A size pill: a rounded box with the words, kept inside the picture (the mockup's pill). */
private fun DrawScope.pill(tm: TextMeasurer, x0: Float, y0: Float, t: String, st: String, W: Float, H: Float) {
    val w = max(24f, t.length * (if (st == "auto") 5.6f else 6.6f) + 14f)
    val x = x0.coerceIn(w / 2 + 2, max(w / 2 + 2, W - w / 2 - 2))
    val y = y0.coerceIn(12f, max(12f, H - 12f))
    val fill = when (st) { "cur" -> PC.blue; "pick" -> PC.room; else -> PC.paper }
    val stroke = when (st) { "cur", "pick" -> PC.blue; "done" -> G.ink2; "bad" -> PC.red; else -> G.ink3 }
    val tl = Offset(x - w / 2, y - 10f)
    drawRoundRect(fill, tl, Size(w, 20f), CornerRadius(10f))
    drawRoundRect(stroke, tl, Size(w, 20f), CornerRadius(10f), style = Stroke(1f, pathEffect = if (st == "auto") PathEffect.dashPathEffect(floatArrayOf(3f, 2f)) else null))
    val col = when (st) { "cur" -> Color.White; "todo", "auto" -> G.ink3; "bad" -> PC.red; "pick" -> PC.blue; else -> G.ink }
    val style = TextStyle(fontFamily = Jakarta, fontSize = (if (st == "auto") 10f else 11f).toSp(), fontWeight = if (st == "todo" || st == "auto") FontWeight.Bold else FontWeight.ExtraBold,
        fontStyle = if (st == "auto") FontStyle.Italic else FontStyle.Normal, color = col)
    val lay = tm.measure(t, style)
    drawText(lay, topLeft = Offset(x - lay.size.width / 2f, y - lay.size.height / 2f))
}

private fun DrawScope.drawPlan(m: PlanModel, mir: Boolean, rot: Int, o: PlanLook, letters: List<String>, auto: String, gapWord: String, tm: TextMeasurer, H: Float, glow: Float) {
    if (m.pts.size < 2) return
    val W = VB
    val f = Fit(m, mir, rot, W, H, o.pad, o.rp)
    val poly = m.pts.map { f.m(it) }
    val sg = if (area2(poly) >= 0) 1f else -1f
    val cen = Offset(poly.sumOf { it.x.toDouble() }.toFloat() / poly.size, poly.sumOf { it.y.toDouble() }.toFloat() / poly.size)
    if (m.gap == null) drawPath(Path().apply { moveTo(poly[0].x, poly[0].y); poly.drop(1).forEach { lineTo(it.x, it.y) }; close() }, PC.room)
    else drawPath(Path().apply { moveTo(poly[0].x, poly[0].y); poly.drop(1).forEach { lineTo(it.x, it.y) }; close() }, PC.room.copy(alpha = PC.room.alpha * .6f))
    val labels = ArrayList<PillAt>()
    fun let(i: Int) = letters.getOrElse(i) { "?" }
    m.edges.forEachIndexed { i, e ->
        val a = f.m(e.a); val b = f.m(e.b)
        val st = eState(e, i, o)
        if (st == "cur") line(a, b, PC.blue, 16f, alpha = glow)
        when (st) {
            "todo" -> line(a, b, G.ink3, 2.5f)
            "auto" -> line(a, b, G.ink3, 2f, floatArrayOf(6f, 5f))
            "bad" -> line(a, b, PC.red, 2.5f, floatArrayOf(6f, 5f))
            "cur" -> line(a, b, PC.blue, 5f)
            "pick" -> line(a, b, PC.blue, 3.5f, floatArrayOf(2f, 6f), .9f)
            else -> line(a, b, G.ink2, 3f)
        }
        val d = b - a; val L = d.getDistance().coerceAtLeast(1f)
        val nx = sg * d.y / L; val ny = -sg * d.x / L
        val off = if (st == "cur") 17f else 14f
        if (!o.nolab && !(st == "auto" && !o.final && o.sel == null && L < 52f)) {
            val t = when {
                st == "pick" -> let(i)
                st == "bad" -> (if (e.len < 0) "−" else "") + o.fmt(abs(e.len))
                o.sel != null -> if (st == "cur") let(i) + " · " + o.fmt(e.len) else o.fmt(e.len)
                o.final -> o.fmt(e.len)
                st == "cur" -> o.liveTxt ?: "?"
                st == "done" -> o.fmt(e.len)
                st == "todo" -> let(i)
                else -> auto
            }
            val px = (a.x + b.x) / 2 + nx * off; val py = (a.y + b.y) / 2 + ny * off
            labels += PillAt(px, py, nx, ny, t, st)
        }
    }
    o.ops.forEach { drawOp(it, m, f, sg, false, tm) }
    o.preview?.let { drawOp(it, m, f, sg, true, tm) }
    m.dims.forEach { d ->
        val a = f.m(d.a); val b = f.m(d.b)
        val st = if (o.final || o.sel != null) "done" else if (o.cur == d.asked) "cur" else if (d.asked in o.done) "done" else "todo"
        if (st == "cur") line(a, b, PC.blue, 16f, alpha = glow)
        when (st) {
            "cur" -> line(a, b, PC.blue, 3f)
            "done" -> line(a, b, G.ink2, 1.5f, floatArrayOf(4f, 4f))
            else -> line(a, b, G.ink3, 1.5f, floatArrayOf(4f, 4f))
        }
        if (!o.nolab) {
            val mx = (a.x + b.x) / 2; val my = (a.y + b.y) / 2
            val dd = b - a; val L = dd.getDistance().coerceAtLeast(1f)
            var nx = -dd.y / L; var ny = dd.x / L
            if (d.kind == "w" && nx * (cen.x - mx) + ny * (cen.y - my) < 0) { nx = -nx; ny = -ny }
            val t = d.label(st, o)
            val k = if (d.kind == "w") 13f else 26f
            labels += PillAt(mx + nx * k, my + ny * k, nx, ny, t, st)
        }
    }
    if (o.diagK != null && o.diagK < m.pts.size) {
        val a = f.m(m.pts[0]); val b = f.m(m.pts[o.diagK])
        if (o.diagCur) line(a, b, PC.blue, 16f, alpha = glow)
        if (o.diagCur) line(a, b, PC.blue, 3f) else line(a, b, G.ink3, 1.5f, floatArrayOf(5f, 5f))
        if (!o.nolab && o.diagTxt != null) labels += PillAt((a.x + b.x) / 2, (a.y + b.y) / 2, 0f, 0f, o.diagTxt, if (o.diagCur) "cur" else "done")
    }
    m.gap?.let { (ga0, gb0) ->
        val ga = f.m(ga0); val gb = f.m(gb0)
        line(ga, gb, PC.red, 2.5f, floatArrayOf(3f, 4f))
        if (!o.nolab) labels += PillAt((ga.x + gb.x) / 2, (ga.y + gb.y) / 2, 0f, 0f, gapWord + " " + o.fmt(m.gapLen), "bad")
    }
    if (o.corner != null && o.corner < m.edges.size) {
        val c = f.m(m.edges[o.corner].a)
        drawCircle(PC.blue, 6.5f, c); drawCircle(PC.paper, 6.5f, c, style = Stroke(2.5f))
    }
    // pills of short walls meeting at a corner would sit on each other: the asked one stays put, the others step
    // further out from their wall until they are clear (a few tries)
    val placed = ArrayList<androidx.compose.ui.geometry.Rect>()
    labels.sortedBy { if (it.st == "cur") 0 else 1 }.forEach { l ->
        // out from the wall first, then along it (a pill pushed against the picture's edge cannot go further out)
        val tx = -l.ny; val ty = l.nx
        val tries = listOf(0f to 0f, 12f to 0f, 24f to 0f, 36f to 0f, 0f to 18f, 0f to -18f, 0f to 36f, 0f to -36f, 12f to 30f, 12f to -30f)
        val (x, y) = tries.asSequence().map { (n, t) -> (l.x + l.nx * n + tx * t) to (l.y + l.ny * n + ty * t) }
            .firstOrNull { (x, y) -> placed.none { it.overlaps(pillRect(x, y, l.t, l.st, W, H)) } } ?: (l.x to l.y)
        placed += pillRect(x, y, l.t, l.st, W, H)
        pill(tm, x, y, l.t, l.st, W, H)
    }
}

/** A bay size's pill: "?" or the live value while asked, "eni" / "chuq." before, the value after. */
private fun PlanDim.label(st: String, o: PlanLook) = when (st) {
    "cur" -> o.liveTxt ?: "?"
    "todo" -> if (kind == "w") o.dimWords.first else o.dimWords.second
    else -> o.dimTxt[asked] ?: o.fmt(value)
}

/** An opening or a site point, as the mockup's opSvg: the door's gap, leaf and swing, the window's blue glass, a lettered dot. */
private fun DrawScope.drawOp(it: PlanOp, m: PlanModel, f: Fit, sg: Float, prev: Boolean, tm: TextMeasurer) {
    val e = m.edges.getOrNull(it.wall) ?: return
    val a = f.m(e.a); val b = f.m(e.b)
    val d = b - a; val L = d.getDistance().coerceAtLeast(1f)
    val ux = d.x / L; val uy = d.y / L
    val nx = -sg * d.y / L; val ny = sg * d.x / L
    val al = if (prev) .6f else 1f
    val dd = it.dist * f.s; val w = it.w * f.s
    val p0 = Offset(a.x + ux * dd, a.y + uy * dd); val p1 = Offset(a.x + ux * (dd + w), a.y + uy * (dd + w))
    if ((it.kind == "door" || it.kind == "window") && it.w <= 0) {
        drawCircle(PC.blue.copy(alpha = al), 5f, p0); drawCircle(PC.paper.copy(alpha = al), 5f, p0, style = Stroke(2.5f)); return
    }
    when (it.kind) {
        "door" -> {
            val tip = Offset(p0.x + nx * w, p0.y + ny * w)
            line(p0, p1, PC.paper, 7f, alpha = al)
            line(p0, tip, G.ink, 2f, alpha = al)
            // the swing: a quarter circle from the door's far end to the leaf's tip, around its hinge
            val path = Path()
            val steps = 16
            val r = w
            val a0 = kotlin.math.atan2((p1.y - p0.y).toDouble(), (p1.x - p0.x).toDouble())
            val a1 = kotlin.math.atan2((tip.y - p0.y).toDouble(), (tip.x - p0.x).toDouble())
            var da = a1 - a0
            while (da > Math.PI) da -= 2 * Math.PI
            while (da < -Math.PI) da += 2 * Math.PI
            for (k in 0..steps) {
                val an = a0 + da * k / steps
                val q = Offset(p0.x + (r * kotlin.math.cos(an)).toFloat(), p0.y + (r * kotlin.math.sin(an)).toFloat())
                if (k == 0) path.moveTo(q.x, q.y) else path.lineTo(q.x, q.y)
            }
            drawPath(path, G.ink3.copy(alpha = al), style = Stroke(1.2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f))))
        }
        "window" -> { line(p0, p1, PC.win, 6f, alpha = al); line(p0, p1, PC.paper, 1.6f, alpha = al) }
        else -> {
            val q = Offset(p0.x + nx * 11f, p0.y + ny * 11f)
            drawCircle(PC.opC(it.kind).copy(alpha = al), 8.5f, q)
            drawCircle(PC.paper.copy(alpha = al), 8.5f, q, style = Stroke(2f))
            val lay = tm.measure(PC.opL(it.kind), TextStyle(fontFamily = Jakarta, fontSize = 10f.toSp(), fontWeight = FontWeight.ExtraBold, color = Color.White))
            drawText(lay, topLeft = Offset(q.x - lay.size.width / 2f, q.y - lay.size.height / 2f), alpha = al)
        }
    }
}

/* ---------------- the shape cards' pictures ---------------- */

/** Each shape's outline with its usual sizes, for the cards (the mockup's shapeThumb with the defaults). */
val THUMBS: Map<String, List<P2>> = mapOf(
    "rect" to listOf(P2(0.0, 0.0), P2(3400.0, 0.0), P2(3400.0, 2600.0), P2(0.0, 2600.0)),
    "L" to listOf(P2(0.0, 0.0), P2(1800.0, 0.0), P2(1800.0, 1800.0), P2(4200.0, 1800.0), P2(4200.0, 3600.0), P2(0.0, 3600.0)),
    "U" to listOf(P2(0.0, 0.0), P2(1400.0, 0.0), P2(1400.0, 1800.0), P2(3000.0, 1800.0), P2(3000.0, 0.0), P2(4400.0, 0.0), P2(4400.0, 3600.0), P2(0.0, 3600.0)),
    "cut" to listOf(P2(0.0, 0.0), P2(3600.0, 0.0), P2(3600.0, 2200.0), P2(2800.0, 3000.0), P2(0.0, 3000.0)),
    "T" to listOf(P2(0.0, 0.0), P2(4800.0, 0.0), P2(4800.0, 1400.0), P2(3200.0, 1400.0), P2(3200.0, 3600.0), P2(1600.0, 3600.0), P2(1600.0, 1400.0), P2(0.0, 1400.0)),
    "Z" to listOf(P2(0.0, 0.0), P2(2600.0, 0.0), P2(2600.0, 1600.0), P2(4400.0, 1600.0), P2(4400.0, 4000.0), P2(1800.0, 4000.0), P2(1800.0, 2600.0), P2(0.0, 2600.0)),
    "bay" to listOf(P2(0.0, 0.0), P2(1000.0, 0.0), P2(1800.0, -800.0), P2(2600.0, -800.0), P2(3400.0, 0.0), P2(4200.0, 0.0), P2(4200.0, 3600.0), P2(0.0, 3600.0))
)

/** A shape card's picture: the outline (blue when chosen), the bay's mouth dashed; the free sketch a hand-drawn outline with its corners. */
@Composable
fun ShapeThumb(k: String, mir: Boolean, rot: Int, sel: Boolean, modifier: Modifier) {
    Canvas(modifier) {
        val sc = min(size.width / 160f, size.height / 100f)
        val dx = (size.width - 160f * sc) / 2; val dy = (size.height - 100f * sc) / 2
        withTransform({ translate(dx, dy); scale(sc, sc, pivot = Offset.Zero) }) {
            if (k == "free") {
                val p = androidx.compose.ui.graphics.vector.PathParser().parsePathString("M40 24C62 21 96 25 118 22C121 36 119 44 121 55C110 56 101 53 92 56C93 65 95 72 95 80C75 79 56 82 38 79C37 60 41 42 40 24Z").toPath()
                drawPath(p, PC.room)
                drawPath(p, if (sel) PC.blue else G.ink, style = Stroke(2.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                listOf(40f to 24f, 118f to 22f, 121f to 55f, 92f to 56f, 95f to 80f, 38f to 79f).forEach { (x, y) -> drawCircle(PC.blue, 3.5f, Offset(x, y)) }
                val pen = androidx.compose.ui.graphics.vector.PathParser().parsePathString("M0 22l4-1L17 8l-3-3L1 18z").toPath()
                withTransform({ translate(124f, 62f); rotate(10f, Offset.Zero) }) { drawPath(pen, PC.blue, style = Stroke(2f, join = StrokeJoin.Round)) }
                return@withTransform
            }
            val pts = THUMBS[k] ?: return@withTransform
            val m = PlanModel(pts, emptyList())
            val f = Fit(m, mir, rot, 160f, 100f, 14f, 0f)
            val q = pts.map { f.m(it) }
            val path = Path().apply { moveTo(q[0].x, q[0].y); q.drop(1).forEach { lineTo(it.x, it.y) }; close() }
            drawPath(path, PC.room)
            drawPath(path, if (sel) PC.blue else G.ink, style = Stroke(2.2f, join = StrokeJoin.Round))
            if (k == "bay") line(f.m(P2(1000.0, 0.0)), f.m(P2(3400.0, 0.0)), G.ink3, 1.5f, floatArrayOf(4f, 3f))
        }
    }
}

/** The height step's picture: a wall with a door and a window, the height glowing on the right with its pill. */
@Composable
fun HeightPic(txt: String, floor: String, ceil: String, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val glow by rememberInfiniteTransition(label = "hglow").animateFloat(.22f, .42f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "hglowA")
    Canvas(modifier) {
        val k = min(size.width / VB, size.height / 198f)
        val dx = (size.width - VB * k) / 2; val dy = (size.height - 198f * k) / 2
        withTransform({ translate(dx, dy); scale(k, k, pivot = Offset.Zero) }) {
            drawRect(PC.room, Offset(60f, 26f), Size(190f, 132f))
            line(Offset(44f, 158f), Offset(262f, 158f), G.ink2, 3f)
            line(Offset(44f, 26f), Offset(262f, 26f), G.ink3, 2.5f)
            drawRect(G.ink3, Offset(88f, 72f), Size(44f, 86f), style = Stroke(1.5f))
            drawRect(G.ink3, Offset(168f, 62f), Size(58f, 46f), style = Stroke(1.5f))
            line(Offset(197f, 62f), Offset(197f, 108f), G.ink3, 1.3f)
            line(Offset(290f, 28f), Offset(290f, 156f), PC.blue, 16f, alpha = glow)
            line(Offset(290f, 28f), Offset(290f, 156f), PC.blue, 5f)
            line(Offset(282f, 26f), Offset(298f, 26f), PC.blue, 5f)
            line(Offset(282f, 158f), Offset(298f, 158f), PC.blue, 5f)
            pill(tm, 290f, 92f, txt, "cur", VB, 198f)
            val st = TextStyle(fontFamily = Jakarta, fontSize = 11f.toSp(), fontWeight = FontWeight.Bold, color = G.ink3)
            tm.measure(ceil, st).let { drawText(it, topLeft = Offset(155f - it.size.width / 2f, 16f - it.size.height / 2f)) }
            tm.measure(floor, st).let { drawText(it, topLeft = Offset(155f - it.size.width / 2f, 172f - it.size.height / 2f)) }
        }
    }
}

/** The openings step's picture buttons (the mockup's OP icons, 40 × 40). */
@Composable
fun OpIcon(kind: String, color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val k = min(size.width, size.height) / 40f
        withTransform({ scale(k, k, pivot = Offset.Zero) }) {
            val s = Stroke(2.2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
            fun p(d: String) = androidx.compose.ui.graphics.vector.PathParser().parsePathString(d).toPath()
            when (kind) {
                "door" -> { drawRoundRect(color, Offset(11f, 5f), Size(18f, 29f), CornerRadius(1.5f), style = s); drawCircle(color, 1.4f, Offset(25f, 20f)); drawPath(p("M5 34h30"), color, style = s) }
                "window" -> { drawRoundRect(PC.win.copy(alpha = .22f), Offset(6f, 8f), Size(28f, 22f), CornerRadius(1.5f)); drawRoundRect(color, Offset(6f, 8f), Size(28f, 22f), CornerRadius(1.5f), style = s); drawPath(p("M20 8v22M6 19h28M4 34h32"), color, style = s) }
                "water" -> { drawPath(p("M6 15h17a6 6 0 016 6v3"), color, style = s); drawPath(p("M15 15V9M10 9h10"), color, style = s)
                    val drop = p("M29 29c0 2.2-1.5 3.5-3.2 3.5S22.6 31.2 22.6 29c0-2.6 3.2-5.6 3.2-5.6s3.2 3 3.2 5.6z"); drawPath(drop, PC.opC("water")); drawPath(drop, PC.opC("water"), style = s) }
                "sewer" -> { drawCircle(color, 13f, Offset(20f, 20f), style = s); drawPath(p("M12 15h16M10 20h20M12 25h16"), color, style = s) }
                else -> { drawPath(p("M5 33h30M10 33V24h20v9"), color, style = s)
                    val fl = p("M20 4c3 3.6 5.2 6.3 5.2 9.2a5.2 5.2 0 01-10.4 0c0-1.7.8-3.1 1.9-4.2.2 1.7 1 2.6 2.1 2.6 0-2.7.6-4.9 1.2-7.6z"); drawPath(fl, PC.opC("gas")); drawPath(fl, PC.opC("gas"), style = s) }
            }
        }
    }
}
