package uz.metrx.app.ui.editor

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.data.Room
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.Theme
import kotlin.math.max
import kotlin.math.min

/**
 * A room's small plan (prototype miniPlan / thumbSVG): the walls as a solid ring once measured (dashed while not),
 * doors and windows as gaps, and on bigger thumbnails the name, the floor area and the two side lengths. Drawn on paper:
 * the light colours stay in the dark theme.
 */
@Composable
fun RoomThumb(r: Room, label: String, unit: LenUnit, english: Boolean, snap: Boolean, detailed: Boolean, modifier: Modifier = Modifier) {
    val tm = rememberTextMeasurer()
    Canvas(modifier) { Theme.onPaper {
        val den = density
        val pad = if (detailed) 22f * den else 6f * den
        val outline: List<Offset>
        val solid: Boolean
        if (r.isPoly) {
            val g = polyGeo(r, snap)
            outline = g.verts.map { Offset(it.x.toFloat(), it.y.toFloat()) }
            solid = g.solved
        } else {
            val a = r.dim("A"); val b = r.dim("B")
            val L = (a.v ?: a.pending?.mm ?: 5000).toFloat(); val W = (b.v ?: b.pending?.mm ?: 4000).toFloat()
            outline = listOf(Offset(0f, 0f), Offset(L, 0f), Offset(L, W), Offset(0f, W))
            solid = a.v != null && b.v != null
        }
        val minX = outline.minOf { it.x }; val maxX = outline.maxOf { it.x }
        val minY = outline.minOf { it.y }; val maxY = outline.maxOf { it.y }
        val bw = max(1f, maxX - minX); val bh = max(1f, maxY - minY)
        val s = min((size.width - 2 * pad) / bw, (size.height - 2 * pad) / bh)
        val ox = (size.width - bw * s) / 2f - minX * s; val oy = (size.height - bh * s) / 2f - minY * s
        val pts = outline.map { Offset(ox + it.x * s, oy + it.y * s) }
        val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        val ink = Color(0xFF0E1C36)
        drawPath(path, Color.White)
        if (solid) drawPath(path, ink, style = Stroke(max(2f * den, (if (detailed) 2.6f else 1.6f) * den), join = StrokeJoin.Miter))
        else drawPath(path, Color(0xFF5F6B82), style = Stroke(1.5f * den, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f * den, 3f * den))))
        // doors and windows as gaps in the wall (rect rooms)
        if (!r.isPoly && solid) r.openings.forEach { o ->
            val i = "ABCD".indexOf(o.wall).takeIf { it >= 0 } ?: return@forEach
            val a = pts[i]; val b = pts[(i + 1) % 4]
            val d = b - a; val len = kotlin.math.hypot(d.x, d.y); if (len == 0f) return@forEach
            val u = Offset(d.x / len, d.y / len)
            val p0 = a + u * (o.off * s); val p1 = a + u * ((o.off + o.w) * s)
            drawLine(Color.White, p0, p1, 3.4f * den)
            if (o.type == "window") drawLine(ink, p0, p1, .8f * den)
        }
        if (!detailed) return@onPaper
        val a = areas(r, snap)
        val cx = (pts.minOf { it.x } + pts.maxOf { it.x }) / 2f; val cy = (pts.minOf { it.y } + pts.maxOf { it.y }) / 2f
        val name = tm.measure(label.uppercase(), TextStyle(fontFamily = Jakarta, fontSize = 8.5.sp, fontWeight = FontWeight.Bold, letterSpacing = .06.em, color = ink))
        drawText(name, topLeft = Offset(cx - name.size.width / 2f, cy - name.size.height))
        val ar = tm.measure((if (a != null) fmtArea(a.floor, english) else "?") + " m²", TextStyle(fontFamily = PlexCond, fontSize = 9.sp, color = Color(0xFF3E4A61)))
        drawText(ar, topLeft = Offset(cx - ar.size.width / 2f, cy))
        if (!r.isPoly) {
            val st = TextStyle(fontFamily = PlexCond, fontSize = 8.5.sp, color = Color(0xFF3E4A61))
            val top = tm.measure(fmtLen(r.dim("A").v, unit, english), st)
            drawText(top, topLeft = Offset(cx - top.size.width / 2f, pts[0].y - top.size.height - 3f * den))
            val left = tm.measure(fmtLen(r.dim("B").v, unit, english), st)
            val lc = Offset(pts[0].x - left.size.height / 2f - 4f * den, cy)
            rotate(-90f, lc) { drawText(left, topLeft = Offset(lc.x - left.size.width / 2f, lc.y - left.size.height / 2f)) }
        }
    } }
}
