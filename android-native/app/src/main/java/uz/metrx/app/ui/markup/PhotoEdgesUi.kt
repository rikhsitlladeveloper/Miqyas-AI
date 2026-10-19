package uz.metrx.app.ui.markup

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.data.Item
import uz.metrx.app.data.PhotoFiles
import uz.metrx.app.geo.ESnap
import uz.metrx.app.geo.EdgeFinder
import uz.metrx.app.geo.PhotoEdges
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * Photo edge measuring, part 2 on the phone: the photo's edges found once when it opens (in the background, on a
 * small grey copy), and drawn faintly over it; the edge or corner a line's end is stuck to turns blue.
 */

/** The edges of a photo item's picture in its units, or null while they are still being found. */
@Composable
fun rememberPhotoEdges(it: Item): PhotoEdges? {
    val ctx = LocalContext.current
    val v by produceState<PhotoEdges?>(null, it.src, it.W, it.hh) {
        value = if (it.kind != "photo" || it.src == null) PhotoEdges.NONE
        else withContext(Dispatchers.Default) { findEdges(ctx, it.src, it.W.toFloat(), it.hh.toFloat()) }
    }
    return v
}

/** Decodes the photo small, makes it grey and finds its edges (none if the file cannot be read). */
fun findEdges(ctx: Context, src: String, outW: Float, outH: Float): PhotoEdges = runCatching {
    val b0 = PhotoFiles.load(ctx, src, EdgeFinder.WORK * 2) ?: return PhotoEdges.NONE
    val k = EdgeFinder.WORK.toFloat() / max(b0.width, b0.height)
    val b = if (k < 1f) Bitmap.createScaledBitmap(b0, (b0.width * k).roundToInt().coerceAtLeast(1), (b0.height * k).roundToInt().coerceAtLeast(1), true) else b0
    val px = IntArray(b.width * b.height); b.getPixels(px, 0, b.width, 0, 0, b.width, b.height)
    val g = FloatArray(px.size) { EdgeFinder.grey(px[it]) }
    EdgeFinder.find(g, b.width, b.height, outW, outH)
}.getOrDefault(PhotoEdges.NONE)

/** The found rectangle while its offer is open (part 3): a light blue fill and a dashed blue outline. */
fun DrawScope.drawRectOffer(r: uz.metrx.app.geo.ERect, ppu: Float) {
    val px = 1f / ppu
    val path = androidx.compose.ui.graphics.Path().apply {
        r.pts.forEachIndexed { i, (x, y) -> if (i == 0) moveTo(x, y) else lineTo(x, y) }; close()
    }
    drawPath(path, EDGE_ON.copy(alpha = .1f))
    drawPath(path, EDGE_ON, style = Stroke(2.5f * density * px, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(8f * density * px, 6f * density * px))))
}

private val EDGE_SHADE = Color(0x4D0F172A)
private val EDGE_LINE = Color(0xB8FFFFFF)
private val EDGE_ON = Color(0xFF3550E0)

/**
 * The edges over the photo, in item units: faint white lines with a thin dark shadow so they read on light and dark
 * photos, small rings at the corners; [stuck] edges and corners blue. [ppu] is screen pixels per item unit.
 */
fun DrawScope.drawPhotoEdges(e: PhotoEdges, ppu: Float, stuck: List<ESnap>) {
    val px = 1f / ppu
    val on = stuck.flatMap { it.segs }.toSet()
    e.segs.forEachIndexed { i, s ->
        val a = Offset(s.x1, s.y1); val b = Offset(s.x2, s.y2)
        if (i in on) {
            drawLine(Color.White.copy(alpha = .9f), a, b, 6f * density * px, StrokeCap.Round)
            drawLine(EDGE_ON, a, b, 3f * density * px, StrokeCap.Round)
        } else {
            drawLine(EDGE_SHADE, a, b, 3f * density * px, StrokeCap.Round)
            drawLine(EDGE_LINE, a, b, 1.5f * density * px, StrokeCap.Round)
        }
    }
    e.corners.forEach { c ->
        val p = Offset(c.x, c.y)
        drawCircle(Color.White.copy(alpha = .9f), 4.5f * density * px, p)
        drawCircle(Color(0x730F172A), 4.5f * density * px, p, style = Stroke(1.5f * density * px))
    }
    stuck.filter { it.corner }.forEach { s ->
        e.corners.firstOrNull { it.a == s.a && it.b == s.b }?.let { c -> drawCircle(EDGE_ON, 11f * density * px, Offset(c.x, c.y), style = Stroke(3f * density * px)) }
    }
}
