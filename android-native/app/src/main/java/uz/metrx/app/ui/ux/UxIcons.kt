package uz.metrx.app.ui.ux

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import uz.metrx.app.ui.icons.ICONS
import uz.metrx.app.ui.icons.MIcon

/** The few icons of the UX upgrades that the app's sprite has not (24 × 24; [fill] drawn filled), from the approved mockup. */
private val UX = mapOf(
    "tg" to (true to listOf("M21.6 3.3L2.9 10.5c-1 .4-1 1.7 0 2l4.7 1.5 1.8 5.7c.2.7 1.1.9 1.7.4l2.7-2.4 4.8 3.5c.7.5 1.6.1 1.8-.7l3-15.2c.2-.9-.7-1.6-1.6-1.2zM9.8 14.4l8.5-7-6.8 8-.4 3.4z")),
    "mic" to (false to listOf("M9 6a3 3 0 0 1 6 0v5a3 3 0 0 1 -6 0z", "M5 11a7 7 0 0 0 14 0M12 18v3")),
    "vib" to (false to listOf("M10 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-4a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2z", "M4.5 9v6M19.5 9v6M2 11v2M22 11v2")),
    "dl" to (false to listOf("M12 4v11M7 10l5 5 5-5M5 20h14")),
    "wifi" to (false to listOf("M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01M2 9a15 15 0 0 1 20 0")),
    "down" to (false to listOf("M12 5v14M6 13l6 6 6-6")),
    "palette" to (false to listOf("M12 3a9 9 0 1 0 0 18c1.2 0 2-.8 2-2 0-.6-.3-1-.6-1.4-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2H17a4 4 0 0 0 4-4c0-4.1-4-7.3-9-7.3z"))
)
private val cache = HashMap<String, Path>()
private fun path(d: String): Path = cache.getOrPut(d) { PathParser().parsePathString(d).toPath() }

/** An icon of the sprite, or one of the UX upgrades' own. */
@Composable
fun UxIcon(name: String, color: Color, size: Dp = 20.dp, strokeWidth: Float = 2f, modifier: Modifier = Modifier) {
    val def = UX[name]
    if (def == null || ICONS.containsKey(name)) { MIcon(name, color, size, strokeWidth, modifier); return }
    Canvas(modifier.size(size)) {
        val k = this.size.minDimension / 24f
        scale(k, k, pivot = androidx.compose.ui.geometry.Offset.Zero) {
            def.second.forEach { d ->
                if (def.first) drawPath(path(d), color, style = Fill)
                else drawPath(path(d), color, style = Stroke(strokeWidth, cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
        }
    }
}
