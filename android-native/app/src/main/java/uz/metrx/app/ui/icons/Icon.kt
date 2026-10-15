package uz.metrx.app.ui.icons

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

private val cache = HashMap<String, Path>()
private fun path(d: String): Path = cache.getOrPut(d) { PathParser().parsePathString(d).toPath() }

private fun parseColor(s: String, current: Color): Color? = when {
    s == "none" -> null
    s == "currentColor" -> current
    s.startsWith("#") -> {
        val h = s.drop(1).let { if (it.length == 3) it.map { c -> "$c$c" }.joinToString("") else it }
        Color(0xFF000000 or h.toLong(16))
    }
    s == "#fff" || s == "white" -> Color.White
    else -> current
}

/** Draws a prototype icon (stroke style: round caps and joins, no fill) into the current DrawScope. */
fun DrawScope.drawIcon(name: String, color: Color, strokeWidth: Float = 2f, box: Size = size) {
    val def = ICONS[name] ?: return
    val k = minOf(box.width / def.w, box.height / def.h)
    withTransform({ scale(k, k, pivot = androidx.compose.ui.geometry.Offset.Zero) }) {
        for (part in def.parts) {
            val p = path(part.d)
            val alpha = part.opacity ?: 1f
            // As in the sprite's CSS: no fill unless a shape sets one; every shape is stroked in the current colour unless it says otherwise.
            part.fill?.let { f -> parseColor(f, color)?.let { drawPath(p, it, alpha = alpha, style = Fill) } }
            val stroke = if (part.stroke != null) parseColor(part.stroke, color) else color
            if (stroke != null)
                drawPath(p, stroke, alpha = alpha, style = Stroke(width = part.strokeWidth ?: strokeWidth, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}

@Composable
fun MIcon(name: String, color: Color, size: Dp = 22.dp, strokeWidth: Float = 2f, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) { drawIcon(name, color, strokeWidth) }
}

/** An icon from raw SVG path data in a 24 × 24 box (for the few drawings that are not in the sprite). */
@Composable
fun PathIcon(d: String, color: Color, size: Dp = 22.dp, strokeWidth: Float = 2f, modifier: Modifier = Modifier, viewBox: Float = 24f) {
    Canvas(modifier.size(size)) {
        val k = this.size.minDimension / viewBox
        scale(k, k, pivot = androidx.compose.ui.geometry.Offset.Zero) {
            drawPath(path(d), color, style = Stroke(width = strokeWidth, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}
