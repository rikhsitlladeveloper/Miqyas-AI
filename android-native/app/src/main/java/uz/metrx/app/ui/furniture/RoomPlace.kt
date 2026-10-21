package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Foot
import uz.metrx.app.furniture.Frame
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.PlanPt
import uz.metrx.app.furniture.PlanWall
import uz.metrx.app.furniture.Pose
import uz.metrx.app.furniture.W_GAP_SIDE
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.canStandFree
import uz.metrx.app.furniture.footsOf
import uz.metrx.app.furniture.frameOf
import uz.metrx.app.furniture.inside
import uz.metrx.app.furniture.islandPoseIn
import uz.metrx.app.furniture.mainFrame
import uz.metrx.app.furniture.poseOf
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.ui.theme.G
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.min
import kotlin.math.roundToInt

/** What a drag moves: a piece along the walls, a corner kitchen into another corner, or a piece that may stand anywhere. */
private enum class Drag { SLIDE, CORNER, FREE }

/** Where the finger took hold: the island or the main part, [ga] along it and [gn] out from its back. */
private class Grab(val island: Boolean, val ga: Double, val gn: Double)

/**
 * The room from above with [g] where it stands, the room's other furniture ([others], grey), its doors and windows.
 * One finger drags [g]: along the walls ([onSlide] the wall and the distance from its start), a corner kitchen into
 * another corner ([onCorner] its first wall), a desk anywhere ([onPose]; near a wall it snaps back on it), the island
 * anywhere ([onIsland]). [red]: it gets in the way of something.
 */
@Composable
internal fun PlacePlan(room: Room, walls: List<PlanWall>, g: Furniture, others: List<Furniture>, ws: Workshop, red: Boolean, label: String,
                       onSlide: (String, Int) -> Unit, onCorner: (String) -> Unit, onPose: (Pose) -> Unit, onIsland: (Pose) -> Unit) {
    val tm = rememberTextMeasurer()
    val mine = footsOf(g, walls, ws)
    val theirs = others.flatMap { footsOf(it, walls, ws) }
    val cur by rememberUpdatedState(g)
    val slide by rememberUpdatedState(onSlide); val corner by rememberUpdatedState(onCorner)
    val pose by rememberUpdatedState(onPose); val isle by rememberUpdatedState(onIsland)
    var size by remember { mutableStateOf(IntSize.Zero) }
    // the plan fitted into the box with room for the wall letters
    val x0 = walls.minOf { it.p0.x }; val y0 = walls.minOf { it.p0.y }
    val spanX = (walls.maxOf { it.p0.x } - x0).coerceAtLeast(1.0); val spanY = (walls.maxOf { it.p0.y } - y0).coerceAtLeast(1.0)
    fun k(): Double = min((size.width - 130.0) / spanX, (size.height - 130.0) / spanY).coerceAtLeast(1e-6)
    fun ox(): Double = (size.width - spanX * k()) / 2
    fun oy(): Double = (size.height - spanY * k()) / 2
    fun scr(q: PlanPt) = Offset((ox() + (q.x - x0) * k()).toFloat(), (oy() + (q.y - y0) * k()).toFloat())
    fun plan(o: Offset) = PlanPt(x0 + (o.x - ox()) / k(), y0 + (o.y - oy()) / k())

    Canvas(Modifier.fillMaxWidth().aspectRatio(1.2f).clip(RoundedCornerShape(18.dp)).border(1.dp, G.rim, RoundedCornerShape(18.dp))
        .onSizeChanged { size = it }
        .semantics { contentDescription = label }
        .pointerInput(walls) {
            var grab: Grab? = null
            detectDragGestures(onDragStart = { at ->
                val q = plan(at); val f = cur
                val isl = footsOf(f, walls, ws).firstOrNull { it.island }
                val fr = if (isl != null && near(isl, q)) islandPoseIn(f, walls)?.let { frameOf(walls, it) } else mainFrame(f, walls)
                grab = fr?.let { Grab(isl != null && near(isl, q), (q - it.o) dot it.u, (q - it.o) dot it.n) }
            }, onDragEnd = { grab = null }, onDragCancel = { grab = null }) { ch, _ ->
                ch.consume()
                val gr = grab ?: return@detectDragGestures
                val q = plan(ch.position); val f = cur
                if (gr.island) {
                    val p = islandPoseIn(f, walls) ?: return@detectDragGestures
                    val fr = frameOf(walls, p) ?: return@detectDragGestures
                    isle(poseOf(walls, p.ref, Frame(q - fr.u * gr.ga - fr.n * gr.gn, fr.u, fr.n)))
                    return@detectDragGestures
                }
                val mode = when { f.kind == "kitchen" && f.walls.count { it != ISLAND } > 1 -> Drag.CORNER; canStandFree(f) -> Drag.FREE; else -> Drag.SLIDE }
                when (mode) {
                    Drag.CORNER -> {
                        // an L goes into the corner nearest the finger; a U takes the wall nearest it as its back wall
                        val n = walls.size
                        if (f.walls.count { it != ISLAND } == 2) walls.minByOrNull { d2(it.p1, q) }?.let { corner(it.id) }
                        else walls.indices.minByOrNull { walls[it].dist(q) }?.let { corner(walls[(it - 1 + n) % n].id) }
                    }
                    Drag.SLIDE -> {
                        val w = walls.minByOrNull { it.dist(q) } ?: return@detectDragGestures
                        slide(w.id, slideX(f, mine(f, walls, ws), w, w.along(q) - gr.ga))
                    }
                    Drag.FREE -> {
                        val fr = mainFrame(f, walls) ?: return@detectDragGestures
                        val m = wardOfF(f) ?: return@detectDragGestures
                        val o = q - fr.u * gr.ga - fr.n * gr.gn
                        // its back near a wall: back on that wall; else where the finger is, turned as it was
                        val mid = o + fr.u * (m.w / 2.0)
                        val w = walls.minByOrNull { it.dist(mid) }
                        if (w != null && w.dist(mid) < 250) slide(w.id, slideX(f, mine(f, walls, ws), w, w.along(mid) - m.w / 2.0))
                        else pose(poseOf(walls, f.pose?.ref ?: walls[0].id, Frame(o, fr.u, fr.n)))
                    }
                }
            }
        }) {
        // a piece's box: filled when it stands on the floor, outlined when it hangs; the one being placed with a heavier front
        fun foot(ft: Foot, c: Color, me: Boolean) {
            val pts = ft.pts.map { scr(it) }
            val pp = footPath(pts)
            if (ft.floor) drawPath(pp, c.copy(alpha = if (me) .28f else .22f))
            drawPath(pp, c, style = Stroke(if (me) 2.5f else 1.5f, pathEffect = if (ft.floor) null else PathEffect.dashPathEffect(floatArrayOf(7f, 5f))))
            if (me && ft.floor) drawLine(c, pts[2], pts[3], 5f)
        }
        val path = Path().apply { walls.forEachIndexed { i, w -> val a = scr(w.p0); if (i == 0) moveTo(a.x, a.y) else lineTo(a.x, a.y) }; close() }
        drawRect(Color(0xFFEFF3FA))
        drawPath(path, Color(0xFFFFFFFF))
        // the other furniture, grey; wall units (they hang) only outlined
        theirs.forEach { foot(it, Color(0xFF94A3B8), false) }
        // doors with their swing, windows in light blue
        room.openings.forEach { op ->
            val w = walls.firstOrNull { it.id == op.wall } ?: return@forEach
            val a = scr(w.at(op.off.toDouble(), 0.0)); val b = scr(w.at((op.off + op.w).toDouble(), 0.0))
            if (op.type == "door") {
                drawLine(Color.White, a, b, 7f)
                val r = (op.w * k()).toFloat()
                val start = Math.toDegrees(atan2(w.u.y, w.u.x)).toFloat()
                val sweep = if (w.u.x * w.n.y - w.u.y * w.n.x > 0) 90f else -90f
                drawArc(Color(0xFF94A3B8), start, sweep, true, Offset(a.x - r, a.y - r), Size(2 * r, 2 * r), alpha = .12f)
                drawArc(Color(0xFF94A3B8), start, sweep, false, Offset(a.x - r, a.y - r), Size(2 * r, 2 * r), style = Stroke(1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f))))
            } else drawLine(Color(0xFF7DD3FC), a, b, 7f)
        }
        drawPath(path, Color(0xFF0F172A), style = Stroke(5f))
        val style = TextStyle(fontSize = 12.sp, color = Color(0xFF475569))
        walls.forEach { w ->
            val lab = tm.measure(w.id, style)
            val c = scr(w.at(w.len / 2, 0.0)); val m = Offset(c.x - (w.n.x * 30).toFloat(), c.y - (w.n.y * 30).toFloat())
            drawText(lab, topLeft = Offset(m.x - lab.size.width / 2f, m.y - lab.size.height / 2f))
        }
        mine.forEach { foot(it, if (red) Color(0xFFDC2626) else Color(0xFF3550E0), true) }
    }
}

/** A piece's box on the plan: filled when it stands on the floor, its front edge heavier for the one being placed. */
private fun DrawScope.footPath(pts: List<Offset>) = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) }; close() }

private fun d2(a: PlanPt, b: PlanPt) = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)

/** Whether [q] is on (or within 150 mm of) box [ft]. */
private fun near(ft: Foot, q: PlanPt) = inside(ft.pts, q) || ft.pts.indices.any { i ->
    val a = ft.pts[i]; val b = ft.pts[(i + 1) % ft.pts.size]; val e = b - a; val l2 = (e dot e).coerceAtLeast(1e-9)
    val t = (((q - a) dot e) / l2).coerceIn(0.0, 1.0); val c = a + e * t
    d2(c, q) < 150.0 * 150.0
}

/** The main part's feet on its wall (the kitchen's first side), for its length. */
private fun mine(f: Furniture, walls: List<PlanWall>, ws: Workshop): List<Foot> {
    val first = if (f.kind == "kitchen") f.walls.firstOrNull { it != ISLAND } else wardOfF(f)?.wall
    return footsOf(f, walls, ws).filter { it.wall == first && it.wall != null }
}

/** The distance from [w]'s start for a piece dragged to [a]: kept on the wall, snapped into a corner near one, to 10 mm. */
private fun slideX(f: Furniture, feet: List<Foot>, w: PlanWall, a: Double): Int {
    val len = if (f.kind == "wardrobe") wardOfF(f)?.w?.toDouble() ?: 0.0 else feet.takeIf { it.isNotEmpty() }?.let { it.maxOf { ft -> ft.a1 } - it.minOf { ft -> ft.a0 } } ?: 0.0
    val gap = if (f.kind == "wardrobe") W_GAP_SIDE.toDouble() else 0.0
    val hi = (w.len - len - gap).coerceAtLeast(gap)
    var x = a.coerceIn(gap, hi)
    if (abs(x - gap) < 150) x = gap
    if (abs(x - hi) < 150) x = hi
    return ((x / 10).roundToInt() * 10).let { if (abs(it - gap) < 10) gap.toInt() else it }
}
