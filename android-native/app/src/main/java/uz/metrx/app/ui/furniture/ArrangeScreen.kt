package uz.metrx.app.ui.furniture

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.withTimeoutOrNull
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.Body
import uz.metrx.app.furniture.F_PASS
import uz.metrx.app.furniture.F_ROT
import uz.metrx.app.furniture.FChecks
import uz.metrx.app.furniture.Frame
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.PlanPt
import uz.metrx.app.furniture.PlanWall
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.bodyOf
import uz.metrx.app.furniture.canBeFree
import uz.metrx.app.furniture.fFlush
import uz.metrx.app.furniture.fGaps
import uz.metrx.app.furniture.fIssues
import uz.metrx.app.furniture.footsOf
import uz.metrx.app.furniture.isFree
import uz.metrx.app.furniture.islandBody
import uz.metrx.app.furniture.nearestWall
import uz.metrx.app.furniture.planSegs
import uz.metrx.app.furniture.planWalls
import uz.metrx.app.furniture.poseAt
import uz.metrx.app.furniture.poseFrame
import uz.metrx.app.furniture.slideOn
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.rooms.FcBtn
import uz.metrx.app.ui.rooms.Kp
import uz.metrx.app.ui.rooms.KeypadOverlay
import uz.metrx.app.ui.rooms.PlanFit
import uz.metrx.app.ui.rooms.PlanLook2
import uz.metrx.app.ui.rooms.RP
import uz.metrx.app.ui.rooms.ReBubble
import uz.metrx.app.ui.rooms.ReIcon
import uz.metrx.app.ui.rooms.ReSession
import uz.metrx.app.ui.rooms.RoundX
import uz.metrx.app.ui.rooms.Zoom
import uz.metrx.app.ui.rooms.drawPlanV2
import uz.metrx.app.ui.rooms.mm
import uz.metrx.app.ui.rooms.planFit
import uz.metrx.app.ui.rooms.reWalls
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UxBar
import uz.metrx.app.ui.ux.UxTop
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * "Mebel joylash" (founder-approved mockup v3, 28 Oct 2026): the room from above with its outer and inner walls, doors
 * and windows, and every piece of its furniture as a box. A piece with its back on a wall slides along it (magnets at
 * the corners and the middle) and moves to another wall brought within 0,5 m; a free piece is dragged anywhere, sticks
 * flush within 60 mm, turns with a round handle in 15° steps (and 90°), and shows four gaps along its own axes (tap
 * to type). Red: on another piece or an inner wall, in a door's room, through a wall; yellow: a passage under 700 mm.
 * The card: name, size (tap: its sizes), Burish 90°, Nusxa, O‘chirish, Devorga yopishtirish / Erkin qilish, ✕, ⌄.
 * Pinch, pan, double tap to fit, undo — as in the room editor.
 */

/** The screen's state: the selected piece (its island), the furniture while a finger moves it, undo, zoom. */
private class ArrState {
    var sel by mutableStateOf<String?>(null)
    var island by mutableStateOf(false)
    var live by mutableStateOf<List<Furniture>?>(null)
    var mag by mutableStateOf<String?>(null)
    var rot by mutableStateOf<Int?>(null)
    var cardMin by mutableStateOf(false)
    val zoom = Zoom()
    val past = mutableStateListOf<Pair<List<Furniture>, String>>()
    val future = mutableStateListOf<Pair<List<Furniture>, String>>()
    var fit: PlanFit? = null
    var handle: Offset? = null
}

/** The room's pieces replaced by [list] in the order's furniture (order kept; gone ones out, new ones at the end). */
private fun withRoom(all: List<Furniture>, rid: String, list: List<Furniture>): List<Furniture> {
    val by = list.associateBy { it.id }
    val kept = all.mapNotNull { f -> if (f.roomId == rid) by[f.id] else f }
    return kept + list.filter { n -> all.none { it.id == n.id } }
}

/** The usual wall the piece's pose is measured from (the room's first outer wall: it never goes away). */
private fun refOf(walls: List<PlanWall>) = walls.firstOrNull { !it.inner }?.id ?: "A"

/** A piece's box and the frame its pose is in: the island, or the piece. */
private fun bodyFrame(f: Furniture, island: Boolean, walls: List<PlanWall>, ws: Workshop): Pair<Body, Frame>? =
    if (island) islandBody(f, walls, ws) else bodyOf(f, walls, ws)?.let { b -> (poseFrame(f, walls) ?: Frame(b.o, b.u, b.n)).let { b to it } }

@Composable
fun FArrangeScreen(rt: Route.FArrange) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val room = p.rooms.firstOrNull { it.id == rt.rid } ?: return
    val snap = app.settings.angleSnap
    val ws = app.settings.workshop
    val st = remember(rt) { ArrState().also { s -> s.sel = rt.sel } }
    val kp = remember(rt) { ReSession("arr:" + rt.rid, "furniture", false, rt.pid, rt.rid, { room }, { }) }
    val walls = remember(room, snap) { planWalls(room, snap) }
    val saved = p.furniture.filter { it.roomId == room.id }
    val fs = st.live ?: saved
    val chk = remember(fs, room, walls) { fIssues(room, fs, walls, ws, snap) }
    val ids = walls.map { it.id }
    val outerIds = walls.filter { !it.inner }.map { it.id }
    val len = { id: String -> wallLen(room, snap, id) }

    fun save(list: List<Furniture>, msg: String, warn: Boolean = false) {
        val before = saved
        if (list == before) { st.live = null; return }
        st.past.add(before to msg); if (st.past.size > 40) st.past.removeAt(0); st.future.clear()
        app.store.update(p.id) { pr -> pr.copy(furniture = withRoom(pr.furniture, room.id, list)) }
        st.live = null
        app.haptic(if (warn) Hap.WARN else Hap.CONFIRM)
        app.toast = ToastMsg(msg, if (warn) ToastKind.INFO else ToastKind.OK, app.t("ux.undo"), onAction = { undoIt(app, st, p.id, room.id) })
    }
    fun set(id: String, msg: String, f: (Furniture) -> Furniture?) {
        val cur = saved.firstOrNull { it.id == id } ?: return
        val n = f(cur) ?: return
        save(saved.map { if (it.id == id) n else it }, msg)
        warnOf(app, chkAfter(room, saved.map { if (it.id == id) n else it }, walls, ws, snap), n)
    }
    // the piece as it stands on a wall, or free where it is now, turned [deg] more
    fun onWall(f: Furniture, wall: String, t: Int): Furniture =
        if (f.kind == "wardrobe") uz.metrx.app.furniture.placed(f.copy(pose = null), listOf(wall), room.id, room.floorId, t, f.keep, len, ws)
        else uz.metrx.app.furniture.placed(uz.metrx.app.furniture.withoutLead(f, len), uz.metrx.app.furniture.placeWalls(f, if (f.walls.count { it != ISLAND } == 1) ids else outerIds, wall),
            room.id, room.floorId, keep = f.keep, len = len, ws = ws, start = t, pose = f.pose)
    fun freeAt(f: Furniture, island: Boolean, c: PlanPt, deg: Double): Furniture? {
        val (b, fr) = bodyFrame(f, island, walls, ws) ?: return null
        val pose = poseAt(walls, if (island) (f.pose?.ref ?: f.walls.first { it != ISLAND }) else refOf(walls), b, fr, c, deg)
        if (island) return f.copy(pose = pose)
        // a wardrobe going free gets its side panels (Free.kt placed)
        return uz.metrx.app.furniture.placed(f, f.walls, room.id, room.floorId, uz.metrx.app.furniture.runStart(f), f.keep, len, ws, pose = pose)
    }
    val sel = fs.firstOrNull { it.id == st.sel }
    if (st.sel != null && sel == null) st.sel = null

    BackHandler { when { kp.kp != null -> kp.kp = null; st.sel != null -> st.sel = null; else -> app.pop() } }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            UxTop(tr("fp.pl.title"), { app.pop() }, eyebrow = dn(room.name, lang) + " · " + tr("fp.pl.sub", "n" to saved.size))
            var cardH by remember { mutableFloatStateOf(0f) }
            Box(Modifier.weight(1f).fillMaxWidth()) {
                PlaceCanvas(app, p.id, st, room, walls, fs, chk, ws, snap, Modifier.fillMaxSize(), cardH,
                    onMove = { st.live = it },
                    onEnd = { list, msg -> save(list, msg); list.firstOrNull { it.id == st.sel }?.let { warnOf(app, fIssues(room, list, walls, ws, snap), it) } },
                    onWallSlide = { f, wall, t -> onWall(f, wall, t) }, onFree = { f, isl, c, deg -> freeAt(f, isl, c, deg) },
                    onKp = { lab, cur, lo, hi, ok -> kp.kp = Kp(lab, cur, lo, hi) { ok(it) } })
                if (saved.isEmpty()) Row(Modifier.align(Alignment.TopCenter).padding(12.dp).clip(RoundedCornerShape(15.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(15.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ReIcon("info", G.cobalt, 16.dp); Text(tr("fp.pl.empty"), style = ui(12.5f, 700, G.ink2))
                }
                if (st.zoom.moved) ZoomPill(st.zoom.z, 10.dp) { st.zoom.reset() }
                if (sel != null) Box(Modifier.align(Alignment.BottomCenter).padding(start = 10.dp, end = 10.dp, bottom = 10.dp).onSizeChanged { cardH = it.height.toFloat() }) {
                    PlaceCard(app, st, sel, chk, walls, ws,
                        onTurn = {
                            val f = sel
                            if (f.kind == "kitchen" && !st.island) { app.say("fp.pl.noTurn", kind = ToastKind.INFO); return@PlaceCard }
                            val (b, _) = bodyFrame(f, st.island, walls, ws) ?: return@PlaceCard
                            set(f.id, app.t("fp.pl.turned", "n" to dn(f.name, lang), "a" to (b.ang + 90) % 360)) { freeAt(it, st.island, b.c, (b.ang + 90).toDouble()) }
                        },
                        onCopy = {
                            val f = sel
                            if (f.kind != "wardrobe") { app.say("fp.pl.noCopy", kind = ToastKind.INFO); return@PlaceCard }
                            val b = bodyOf(f, walls, ws) ?: return@PlaceCard
                            val poly = walls.filter { !it.inner }.map { it.p0 }
                            val at = listOf(b.u * (b.w + 200), b.u * -(b.w + 200), b.n * (b.d + 300)).map { b.c + it }.firstOrNull { uz.metrx.app.furniture.inside(poly, it) } ?: b.c + b.n * (b.d + 300)
                            val nf0 = f.copy(id = uz.metrx.app.data.uid(), name = f.name + " · " + app.t("re.t.copy").lowercase(), created = System.currentTimeMillis())
                            val nf = freeAt(nf0, false, at, b.ang.toDouble()) ?: return@PlaceCard
                            save(saved + nf, app.t("fp.pl.copied", "n" to dn(f.name, lang))); st.sel = nf.id; st.island = false
                        },
                        onDel = {
                            val f = sel
                            save(saved.filter { it.id != f.id }, app.t("fp.pl.gone", "n" to dn(f.name, lang))); st.sel = null
                        },
                        onStick = {
                            val f = sel
                            val b = bodyOf(f, walls, ws) ?: return@PlaceCard
                            val nw = nearestWall(b.c, b.w, walls) ?: run { app.say("fp.pl.noWall", kind = ToastKind.ERROR); return@PlaceCard }
                            val t = (nw.second - b.w / 2).coerceIn(0.0, max(0.0, nw.first.len - b.w)).roundToInt()
                            set(f.id, app.t("fp.pl.stuck", "n" to dn(f.name, lang), "w" to nw.first.id)) { onWall(it, nw.first.id, t) }
                        },
                        onFreeIt = {
                            val f = sel
                            val b = bodyOf(f, walls, ws) ?: return@PlaceCard
                            set(f.id, app.t("fp.pl.freed", "n" to dn(f.name, lang))) { freeAt(it, false, b.c, b.ang.toDouble()) }
                        },
                        onSize = {
                            val f = sel
                            if (f.model.isNotEmpty() && uz.metrx.app.furniture.fModel(f.model) != null) app.push(Route.FSteps(p.id, f.model, f.id)) else app.push(app.designer(p.id, f, step = 1))
                        })
                }
            }
            UxBar(tr("rsh.ready"), null, { app.pop() }, { undoIt(app, st, p.id, room.id) }, st.past.isNotEmpty(), { redoIt(app, st, p.id, room.id) }, st.future.isNotEmpty(), seg = {
                Row(Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .06f)).border(1.dp, G.rim, RoundedCornerShape(14.dp))
                    .clickable(role = Role.Button) { app.push(Route.FGallery(p.id, room.id)) }.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    ReIcon("plus", G.ink, 16.dp); Text(tr("fp.pl.more"), style = ui(13.5f, 700))
                }
            })
        }
        KeypadOverlay(kp)
    }
}

/** The checks with [list] in the room. */
private fun chkAfter(room: Room, list: List<Furniture>, walls: List<PlanWall>, ws: Workshop, snap: Boolean) = fIssues(room, list, walls, ws, snap)

/** A piece that turned red or yellow says so (a warning toast after the change's own). */
private fun warnOf(app: App, c: FChecks, f: Furniture) {
    val red = c.red[f.id]; val yel = c.yel[f.id]
    if (red == null && yel == null) return
    app.haptic(Hap.WARN)
    val why = if (red != null) redText(app, red) else app.t("fp.pl.narrow", "v" to mm(yel!!.minOf { it.gap }))
    val prev = app.toast
    app.toast = ToastMsg(dn(f.name, app.settings.lang) + ": " + why, ToastKind.INFO, prev?.action, prev?.onAction)
}

/** A red reason in words. */
private fun redText(app: App, r: uz.metrx.app.furniture.FRed): String =
    app.t(r.key, *r.vars.map { (k, v) -> k to (if (k == "k") app.t("iw.k.$v").lowercase() else if (k == "n") dn(v.toString(), app.settings.lang) else v) }.toTypedArray())

private fun undoIt(app: App, st: ArrState, pid: String, rid: String) {
    val e = st.past.removeLastOrNull() ?: return
    val cur = app.store.get(pid)?.furniture?.filter { it.roomId == rid } ?: return
    st.future.add(cur to e.second)
    app.store.update(pid) { pr -> pr.copy(furniture = withRoom(pr.furniture, rid, e.first)) }
    st.live = null; app.haptic(Hap.TICK)
    app.toast = ToastMsg(app.t("re.undone", "m" to e.second), ToastKind.OK, app.t("re.redo"), onAction = { redoIt(app, st, pid, rid) })
}

private fun redoIt(app: App, st: ArrState, pid: String, rid: String) {
    val e = st.future.removeLastOrNull() ?: return
    val cur = app.store.get(pid)?.furniture?.filter { it.roomId == rid } ?: return
    st.past.add(cur to e.second)
    app.store.update(pid) { pr -> pr.copy(furniture = withRoom(pr.furniture, rid, e.first)) }
    st.live = null; app.haptic(Hap.TICK)
    app.toast = ToastMsg(app.t("re.redone", "m" to e.second), ToastKind.OK)
}

/* ---------------- the plan ---------------- */

private fun Furniture.isKitchen() = kind == "kitchen"

@Composable
private fun PlaceCanvas(app: App, pid: String, st: ArrState, room: Room, walls: List<PlanWall>, fs: List<Furniture>, chk: FChecks, ws: Workshop, snap: Boolean, modifier: Modifier, cardH: Float,
                        onMove: (List<Furniture>) -> Unit, onEnd: (List<Furniture>, String) -> Unit,
                        onWallSlide: (Furniture, String, Int) -> Furniture, onFree: (Furniture, Boolean, PlanPt, Double) -> Furniture?,
                        onKp: (String, Int, Int, Int, (Int) -> Unit) -> Unit) {
    val tm = rememberTextMeasurer()
    val u = LocalDensity.current.density
    val lang = LocalLang.current
    val rw = reWalls(room, snap)
    BoxWithConstraints(modifier.background(RP.paper)) {
        val W = constraints.maxWidth.toFloat(); val H = constraints.maxHeight.toFloat()
        val fit = planFit(room, rw, Rect(0f, 0f, W, H - (if (st.sel != null) cardH + 8 * u else 0f)), 34 * u, 44 * u, st.zoom.z, st.zoom.ox, st.zoom.oy) ?: return@BoxWithConstraints
        st.fit = fit
        fun M(q: PlanPt) = fit.M(Pt(q.x, q.y))
        val feet = fs.associate { it.id to footsOf(it, walls, ws) }
        val sel = fs.firstOrNull { it.id == st.sel }
        // the fingers: a piece drags at once, its round handle turns it; elsewhere pan and pinch, a double tap fits
        Box(Modifier.fillMaxSize().pointerInput(room, walls) { gestures(app, pid, st, room, walls, ws, snap, onMove, onEnd, onWallSlide, onFree) })
        Canvas(Modifier.fillMaxSize()) {
            drawPlanV2(room, fit, PlanLook2(small = true, lens = false, faceLabels = false), tm, u) { "" }
            val wood = Color(0xFFB7895B)
            fs.forEach { f ->
                val red = chk.red.containsKey(f.id); val yel = chk.yel.containsKey(f.id); val on = f.id == st.sel
                feet[f.id].orEmpty().forEach { ft ->
                    val pts = ft.pts.map { M(it) }
                    val path = Path().apply { pts.forEachIndexed { i, o -> if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }; close() }
                    val c = if (red) RP.red else if (yel) Color(0xFFD97706) else wood
                    if (ft.floor) drawPath(path, c.copy(alpha = if (red) .32f else .24f))
                    drawPath(path, c, style = Stroke((if (on) 1.4f else 1.6f) * u, pathEffect = if (ft.floor) null else PathEffect.dashPathEffect(floatArrayOf(6 * u, 4 * u))))
                    if (ft.floor && pts.size == 4) drawLine(c, pts[2], pts[3], 3f * u, StrokeCap.Round)
                    if (on) drawPath(path, G.cobalt, style = Stroke(2.6f * u))
                }
                // the name in the middle when it fits
                bodyOf(f, walls, ws)?.let { b ->
                    val c0 = M(b.c); val wpx = (b.w * fit.k).toFloat(); val dpx = (b.d * fit.k).toFloat()
                    val lay = tm.measure(dn(f.name, lang), TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = G.ink2), maxLines = 1)
                    if (min(wpx, dpx) > 16 * u && max(wpx, dpx) > lay.size.width + 8) drawText(lay, topLeft = Offset(c0.x - lay.size.width / 2f, c0.y - lay.size.height / 2f))
                }
            }
            // narrow passages: an amber dimension line with its label
            chk.yel.values.flatten().forEach { y ->
                val a = M(y.p0); val b = M(y.p1); val l = max(hypot(b.x - a.x, b.y - a.y), 1f)
                val q = Offset(-(b.y - a.y) / l * 5 * u, (b.x - a.x) / l * 5 * u)
                drawLine(Color(0xFFD97706), a, b, 1.6f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u)))
                drawLine(Color(0xFFD97706), a + q, a - q, 1.6f * u); drawLine(Color(0xFFD97706), b + q, b - q, 1.6f * u)
            }
            // the round handle of a free piece (or the island): turns it in 15° steps
            st.handle = null
            if (sel != null && (isFree(sel) || st.island)) bodyFrame(sel, st.island, walls, ws)?.let { (b, _) ->
                val fe = b.c + b.n * (b.d / 2) + b.u * (b.w * .32); val e = M(fe); val q = M(fe + b.n * 100.0)
                val l = max(hypot(q.x - e.x, q.y - e.y), 1e-3f); val hp = Offset(e.x + (q.x - e.x) / l * 26 * u, e.y + (q.y - e.y) / l * 26 * u)
                drawLine(G.cobalt, e, hp, 1.6f * u)
                drawCircle(Color.White, 13 * u, hp); drawCircle(G.cobalt, 13 * u, hp, style = Stroke(2f * u))
                val k = 16 * u / 24f
                translate(hp.x - 8 * u, hp.y - 8 * u) { scale(k, k, Offset.Zero) {
                    drawPath(androidx.compose.ui.graphics.vector.PathParser().parsePathString("M20 12a8 8 0 11-2.3-5.6 M20 4v5h-5").toPath(), G.cobalt, style = Stroke(2.4f, cap = StrokeCap.Round))
                } }
                st.handle = hp
            }
        }
        // the labels of narrow passages
        val seen = ArrayList<Offset>()
        chk.yel.values.flatten().forEach { y ->
            val a = M(y.p0); val b = M(y.p1); val m = Offset((a.x + b.x) / 2, (a.y + b.y) / 2)
            if (seen.any { hypot(it.x - m.x, it.y - m.y) < 24 * u }) return@forEach
            seen += m
            AmberTag(app.t("fp.pl.pass", "v" to mm(y.gap)), m.x, m.y)
        }
        if (sel != null) Pills(app, st, room, walls, fs, sel, ws, snap, fit, u, onEnd, onWallSlide, onFree, onKp)
        st.rot?.let { a -> st.handle?.let { h -> ReBubble("$a°", h.x, h.y - 30 * u, live = true, small = true) } }
        st.mag?.let { m -> sel?.let { f -> bodyOf(f, walls, ws)?.let { b -> val c = M(b.c + b.n * (b.d / 2 + 260)); ReBubble(app.t("re.mag", "a" to m), c.x, c.y, live = true, small = true) } } }
    }
}

@Composable
private fun BoxScope.AmberTag(text: String, x: Float, y: Float) {
    val d = LocalDensity.current
    Text(text, style = ui(11f, 800, Color.White), maxLines = 1, modifier = Modifier.layoutAt(x, y, d.density).clip(RoundedCornerShape(10.dp)).background(Color(0xFFD97706)).padding(horizontal = 8.dp, vertical = 3.dp))
}

/** Places a small label centred on [x], [y] px, kept inside its box. */
private fun Modifier.layoutAt(x: Float, y: Float, u: Float) = this.then(Modifier.layout { m, cs ->
    val pl = m.measure(cs.copy(minWidth = 0, minHeight = 0))
    val pad = (4 * u).roundToInt()
    val left = (x - pl.width / 2f).roundToInt().coerceIn(pad, max(pad, cs.maxWidth - pl.width - pad))
    val top = (y - pl.height / 2f).roundToInt().coerceIn(pad, max(pad, cs.maxHeight - pl.height - pad))
    layout(pl.width, pl.height) { pl.place(left, top) }
})

/** The selected piece's pills: a wall piece's two distances to its wall's ends, a free piece's four gaps (tap to type). */
@Composable
private fun BoxScope.Pills(app: App, st: ArrState, room: Room, walls: List<PlanWall>, fs: List<Furniture>, f: Furniture, ws: Workshop, snap: Boolean, fit: PlanFit, u: Float,
                           onEnd: (List<Furniture>, String) -> Unit, onWallSlide: (Furniture, String, Int) -> Furniture, onFree: (Furniture, Boolean, PlanPt, Double) -> Furniture?,
                           onKp: (String, Int, Int, Int, (Int) -> Unit) -> Unit) {
    val lang = LocalLang.current
    fun M(q: PlanPt) = fit.M(Pt(q.x, q.y))
    val (b, _) = bodyFrame(f, st.island, walls, ws) ?: return
    val nm = dn(f.name, lang)
    val lines = ArrayList<Pair<Offset, Offset>>()
    if (!isFree(f) && !st.island) {
        val w = walls.firstOrNull { it.id == (if (f.kind == "wardrobe") uz.metrx.app.furniture.wardOfF(f)?.wall else f.walls.firstOrNull { it != ISLAND }) } ?: return
        val t = w.along(b.o).roundToInt().coerceAtLeast(0); val L = w.len.roundToInt(); val hi = max(0, L - b.w.roundToInt()); val dr = (hi - t).coerceAtLeast(0)
        val o = 120.0
        if (t > 5) { val a = M(w.at(0.0, o)); val c = M(w.at(t.toDouble(), o)); lines += a to c
            ReBubble(mm(t), (a.x + c.x) / 2, (a.y + c.y) / 2, small = true, onClick = { onKp(app.t("fp.pl.kpStart", "n" to nm), t, 0, hi) { v -> onEnd(fs.map { if (it.id == f.id) onWallSlide(it, w.id, v) else it }, app.t("fp.pl.distSet", "n" to nm, "v" to mm(v))) } }) }
        if (dr > 5) { val a = M(w.at((t + b.w), o)); val c = M(w.at(w.len, o)); lines += a to c
            ReBubble(mm(dr), (a.x + c.x) / 2, (a.y + c.y) / 2, small = true, onClick = { onKp(app.t("fp.pl.kpEnd", "n" to nm), dr, 0, hi) { v -> onEnd(fs.map { if (it.id == f.id) onWallSlide(it, w.id, hi - v) else it }, app.t("fp.pl.distSet", "n" to nm, "v" to mm(v))) } }) }
    } else {
        val feet = fs.associate { it.id to footsOf(it, walls, ws) }
        val segs = planSegs(room, walls, feet, f.id, snap)
        val sides = listOf("fp.pl.toR", "fp.pl.toL", "fp.pl.toF", "fp.pl.toB")
        fGaps(b, segs).forEachIndexed { k, g ->
            if (g == null || g.gap <= 2) return@forEachIndexed
            val a = M(g.p0); val c = M(g.p1); lines += a to c
            val m = Offset((a.x + c.x) / 2, (a.y + c.y) / 2)
            ReBubble(mm(g.gap), m.x, m.y, live = false, small = true, onClick = {
                onKp(app.t("fp.pl.kpGap", "n" to nm, "s" to app.t(sides[k])), g.gap, 0, 99_999) { v ->
                    val sh = (g.gap - v).toDouble()
                    onFree(f, st.island, b.c + g.dir * sh, b.ang.toDouble())?.let { n -> onEnd(fs.map { if (it.id == f.id) n else it }, app.t("fp.pl.gapSet", "n" to nm, "v" to mm(v))) }
                }
            })
        }
    }
    val cob = G.cobalt
    Canvas(Modifier.fillMaxSize()) { lines.forEach { (a, c) -> drawLine(cob, a, c, 1.3f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))) } }
}

/* ---------------- the fingers ---------------- */

private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.gestures(app: App, pid: String, st: ArrState, room: Room, walls: List<PlanWall>, ws: Workshop, snap: Boolean,
                                                                                onMove: (List<Furniture>) -> Unit, onEnd: (List<Furniture>, String) -> Unit,
                                                                                onWallSlide: (Furniture, String, Int) -> Furniture, onFree: (Furniture, Boolean, PlanPt, Double) -> Furniture?) {
    var lastTap = 0L; var lastAt = Offset.Zero
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val u = density
        val fit = st.fit ?: return@awaitEachGesture
        val p = app.store.get(pid) ?: return@awaitEachGesture
        val fs0 = p.furniture.filter { it.roomId == room.id }
        val p0 = down.position
        fun plan(o: Offset) = fit.MI(o).let { PlanPt(it.x, it.y) }
        val q0 = plan(p0)
        // what is under the finger: the handle, an island, a piece (the one on top first)
        var mode = "tap"; var fid: String? = null; var isl = false
        val h = st.handle
        if (h != null && st.sel != null && hypot(p0.x - h.x, p0.y - h.y) < 22 * u) { mode = "rot"; fid = st.sel; isl = st.island }
        else {
            for (f in fs0.asReversed()) {
                val feet = footsOf(f, walls, ws)
                feet.firstOrNull { it.island && near(it.pts, q0, (12 * u / fit.k).toDouble()) }?.let { fid = f.id; isl = true }
                if (fid == null && feet.any { !it.island && near(it.pts, q0, (12 * u / fit.k).toDouble()) }) fid = f.id
                if (fid != null) break
            }
            if (fid != null) mode = "press"
        }
        val f0 = fs0.firstOrNull { it.id == fid }
        val bf0 = f0?.let { bodyFrame(it, isl, walls, ws) }
        val grabA = f0?.let { f -> if (!isFree(f) && !isl) walls.firstOrNull { it.id == (if (f.kind == "wardrobe") uz.metrx.app.furniture.wardOfF(f)?.wall else f.walls.firstOrNull { w -> w != ISLAND }) }?.let { w -> w.along(q0) - w.along(bf0!!.first.o) } else null }
        val zx0 = st.zoom.ox; val zy0 = st.zoom.oy
        var cur: List<Furniture>? = null; var msg = ""
        var pinch: Triple<Float, Offset, Float>? = null
        while (true) {
            val ev = awaitPointerEvent()
            val pressed = ev.changes.filter { it.pressed }
            if (pressed.isEmpty()) break
            if (pressed.size >= 2) {
                cur = null; onMove(fs0); st.rot = null; st.mag = null
                val a = pressed[0].position; val b = pressed[1].position
                val dd = max(10f, hypot(a.x - b.x, a.y - b.y)); val m = Offset((a.x + b.x) / 2, (a.y + b.y) / 2)
                if (pinch == null) pinch = Triple(dd, m, st.zoom.z)
                else { val (d0, m0, z0) = pinch!!; val nz = (z0 * dd / d0).coerceIn(.6f, 6f)
                    st.zoom.ox = m.x - (m0.x - zx0) * (nz / z0); st.zoom.oy = m.y - (m0.y - zy0) * (nz / z0); st.zoom.z = nz }
                mode = "pinch"; ev.changes.forEach { it.consume() }; continue
            }
            val c = ev.changes.firstOrNull { it.id == down.id } ?: continue
            val pp = c.position; val hyp = hypot(pp.x - p0.x, pp.y - p0.y)
            when (mode) {
                "press" -> if (hyp > 6 * u) { mode = "drag"; st.sel = fid; st.island = isl; app.haptic(Hap.TICK) }
                "tap" -> if (hyp > 8 * u) mode = "pan"
            }
            if (mode == "pan") { st.zoom.ox = zx0 + (pp.x - p0.x); st.zoom.oy = zy0 + (pp.y - p0.y); c.consume(); continue }
            if (f0 == null || bf0 == null) continue
            val q = plan(pp)
            val (b0, _) = bf0
            if (mode == "rot") {
                c.consume()
                val ang = Math.toDegrees(atan2(q.y - b0.c.y, q.x - b0.c.x)) - 90
                val sn = (((Math.round(ang / F_ROT) * F_ROT).toInt() % 360) + 360) % 360
                if (st.rot != sn) app.haptic(Hap.TICK)
                st.rot = sn
                onFree(f0, isl, b0.c, sn.toDouble())?.let { n -> cur = fs0.map { if (it.id == f0.id) n else it }; onMove(cur!!) }
                msg = app.t("fp.pl.turned", "n" to dn(f0.name, app.settings.lang), "a" to sn)
                continue
            }
            if (mode != "drag") continue
            c.consume()
            if (isFree(f0) || isl) {
                val c1 = b0.c + (q - q0)
                // flush with a wall or a piece within 60 mm
                val feet = fs0.associate { it.id to footsOf(it, walls, ws) }
                val segs = planSegs(room, walls, feet, f0.id, snap)
                val (c2, mg) = fFlush(Body(c1 - b0.u * (b0.w / 2) - b0.n * (b0.d / 2), b0.u, b0.n, b0.w, b0.d), segs)
                st.mag = if (mg) app.t("fp.pl.magWall") else null
                onFree(f0, isl, c2, b0.ang.toDouble())?.let { n -> cur = fs0.map { if (it.id == f0.id) n else it }; onMove(cur!!) }
                msg = app.t("fp.pl.movedFree", "n" to dn(f0.name, app.settings.lang))
            } else if (f0.kind == "kitchen" && f0.walls.count { it != ISLAND } > 1) {
                // a corner kitchen goes into the corner nearest the finger
                val outer = walls.filter { !it.inner }; val n = outer.size
                val first = if (f0.walls.count { it != ISLAND } == 2) outer.minByOrNull { hypot(it.p1.x - q.x, it.p1.y - q.y) }?.id
                    else outer.indices.minByOrNull { outer[it].dist(q) }?.let { outer[(it - 1 + n) % n].id }
                if (first != null && first != f0.walls.first()) { val nf = onWallSlide(f0, first, 0); cur = fs0.map { if (it.id == f0.id) nf else it }; onMove(cur!!) }
                msg = app.t("fp.pl.movedWall", "n" to dn(f0.name, app.settings.lang), "w" to (first ?: f0.walls.first()))
            } else {
                val w0 = walls.firstOrNull { it.id == (if (f0.kind == "wardrobe") uz.metrx.app.furniture.wardOfF(f0)?.wall else f0.walls.firstOrNull { it != ISLAND }) } ?: continue
                val (wall, t, mg) = slideOn(walls, w0.id, q, grabA ?: 0.0, b0.w, (12 * u / fit.k).toDouble())
                st.mag = mg?.let { app.t(if (it == "mid") "re.magMid" else "re.magCorner") }
                val nf = onWallSlide(f0, wall, t)
                cur = fs0.map { if (it.id == f0.id) nf else it }; onMove(cur!!)
                val L = walls.firstOrNull { it.id == wall }?.len?.roundToInt() ?: 0
                msg = app.t("fp.pl.slid", "n" to dn(f0.name, app.settings.lang), "w" to wall, "a" to mm(t), "b" to mm(max(0, L - b0.w.roundToInt() - t)))
            }
        }
        st.mag = null; st.rot = null
        when (mode) {
            "drag", "rot" -> { val r = cur; if (r != null) onEnd(r, msg) else onMove(fs0) }
            "tap", "press" -> {
                val now = System.currentTimeMillis()
                if (fid == null && now - lastTap < 320 && hypot(p0.x - lastAt.x, p0.y - lastAt.y) < 26 * u) { st.zoom.reset(); lastTap = 0L; return@awaitEachGesture }
                lastTap = now; lastAt = p0
                if (fid != null) { st.sel = fid; st.island = isl; app.haptic(Hap.TICK) } else if (st.sel != null) st.sel = null
            }
        }
    }
}

/** Whether [q] is on (or within [tol] mm of) the box [pts]. */
private fun near(pts: List<PlanPt>, q: PlanPt, tol: Double) = uz.metrx.app.furniture.inside(pts, q) || pts.indices.any { i ->
    val a = pts[i]; val b = pts[(i + 1) % pts.size]; val e = b - a; val l2 = (e dot e).coerceAtLeast(1e-9)
    val t = (((q - a) dot e) / l2).coerceIn(0.0, 1.0); val c = a + e * t
    hypot(c.x - q.x, c.y - q.y) < tol
}

/* ---------------- the card ---------------- */

@Composable
private fun PlaceCard(app: App, st: ArrState, f: Furniture, chk: FChecks, walls: List<PlanWall>, ws: Workshop,
                      onTurn: () -> Unit, onCopy: () -> Unit, onDel: () -> Unit, onStick: () -> Unit, onFreeIt: () -> Unit, onSize: () -> Unit) {
    val lang = LocalLang.current
    val shape = RoundedCornerShape(22.dp)
    val base = Modifier.fillMaxWidth().shadow(18.dp, shape).clip(shape).background(G.solid).border(1.dp, G.rim, shape)
    val b = bodyFrame(f, st.island, walls, ws)?.first
    val red = chk.red[f.id]; val yel = chk.yel[f.id]
    val free = isFree(f) || st.island
    val where = when {
        st.island -> app.t("fp.pl.island") + " · " + (b?.ang ?: 0) + "°"
        free -> app.t("fp.pl.free", "a" to (b?.ang ?: 0))
        else -> app.t("fp.pl.along", "w" to (f.walls.firstOrNull { it != ISLAND } ?: uz.metrx.app.furniture.wardOfF(f)?.wall ?: ""))
    }
    val size = b?.let { mm(it.w.roundToInt()) + " × " + mm(it.d.roundToInt()) + " mm" } ?: ""
    val badge = @Composable { Box(Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)).background(Color(0xFFB7895B)), contentAlignment = Alignment.Center) { ReIcon("sofa", Color.White, 19.dp) } }
    if (st.cardMin) {
        Row(base.padding(start = 8.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            badge()
            Column(Modifier.weight(1f)) {
                Text(dn(f.name, lang), style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("$size · $where" + if (red != null) " · " + app.t("fp.pl.redS") else if (yel != null) " · " + app.t("fp.pl.yelS") else "", style = num(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            RoundX("up", tr("re.cardOpen")) { st.cardMin = false }
            RoundX("close", tr("re.desel")) { st.sel = null }
        }
        return
    }
    Column(base.padding(start = 12.dp, end = 10.dp, top = 10.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            badge()
            Column(Modifier.weight(1f)) {
                Text(dn(f.name, lang), style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(where, style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            RoundX("down", tr("re.cardMin")) { st.cardMin = true }
            RoundX("close", tr("re.desel")) { st.sel = null }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("fp.pl.size"), style = ui(12f, 700, G.ink2))
            Row(Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).border(1.dp, G.rim, RoundedCornerShape(12.dp))
                .semantics { contentDescription = app.t("fp.pl.size") }.clickable(role = Role.Button, onClick = onSize).padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)) { ReIcon("ruler", G.cobalt2, 15.dp); Text(size, style = num(13f, 800)) }
            Text(tr(if (free) "fp.pl.hintFree" else "fp.pl.hintWall"), style = ui(11f, 600, G.ink3), maxLines = 2, modifier = Modifier.weight(1f))
        }
        if (red != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(horizontal = 12.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReIcon("warn", G.err, 18.dp); Text(app.t("fp.pl.red", "r" to redText(app, red)), style = ui(12.5f, 600, G.err, 1.3f), modifier = Modifier.weight(1f))
        } else if (yel != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(horizontal = 12.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReIcon("warn", G.amberInk, 18.dp); Text(app.t("fp.pl.yel", "v" to mm(yel.minOf { it.gap }), "m" to mm(F_PASS)), style = ui(12.5f, 600, G.ink, 1.3f), modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            FcBtn(tr("fp.pl.turn"), "rotate", modifier = Modifier.weight(1f), onClick = onTurn)
            FcBtn(tr("re.t.copy"), "copy", modifier = Modifier.weight(1f), onClick = onCopy)
            FcBtn(tr("re.t.del"), "trash", red = true, modifier = Modifier.weight(1f), onClick = onDel)
        }
        if (!st.island && canBeFree(f)) Row(Modifier.fillMaxWidth()) {
            if (free) FcBtn(tr("fp.pl.stick"), "stick", modifier = Modifier.weight(1f), onClick = onStick)
            else FcBtn(tr("fp.pl.makeFree"), "freeP", modifier = Modifier.weight(1f), onClick = onFreeIt)
        }
    }
}

/* ---------------- "Qayerga qo‘yamiz?" ---------------- */

/** The two cards' pictures: a box with its back on the top wall and arrows along it; a turned box with its round handle. */
@Composable
private fun WhereThumb(wall: Boolean, modifier: Modifier) {
    val ink = G.ink3; val box = Color(0xFFB7895B); val cob = G.cobalt; val ink2 = G.ink2
    Canvas(modifier) {
        val u = density; val W = size.width; val H = size.height
        val x0 = 12 * u; val y0 = 8 * u; val w = W - 24 * u; val h = H - 16 * u
        drawRect(ink.copy(alpha = .6f), Offset(x0, y0), androidx.compose.ui.geometry.Size(w, h), style = Stroke(1.2f * u))
        if (wall) {
            drawLine(ink2, Offset(x0, y0), Offset(x0 + w, y0), 4 * u)
            val bw = w * .42f; val bx = x0 + (w - bw) / 2
            drawRect(box.copy(alpha = .3f), Offset(bx, y0 + 1 * u), androidx.compose.ui.geometry.Size(bw, h * .3f))
            drawRect(box, Offset(bx, y0 + 1 * u), androidx.compose.ui.geometry.Size(bw, h * .3f), style = Stroke(1.6f * u))
            val yy = y0 + h * .16f
            drawLine(cob, Offset(bx - 8 * u, yy), Offset(bx - 26 * u, yy), 2f * u, StrokeCap.Round)
            drawLine(cob, Offset(bx + bw + 8 * u, yy), Offset(bx + bw + 26 * u, yy), 2f * u, StrokeCap.Round)
        } else {
            val cx = x0 + w / 2; val cy = y0 + h * .55f
            rotate(-18f, Offset(cx, cy)) {
                drawRect(box.copy(alpha = .3f), Offset(cx - w * .19f, cy - h * .16f), androidx.compose.ui.geometry.Size(w * .38f, h * .32f))
                drawRect(box, Offset(cx - w * .19f, cy - h * .16f), androidx.compose.ui.geometry.Size(w * .38f, h * .32f), style = Stroke(1.6f * u))
            }
            drawCircle(cob, 4 * u, Offset(cx, y0 + h * .14f))
            listOf(Offset(0f, 1f), Offset(0f, -1f), Offset(1f, 0f), Offset(-1f, 0f)).forEach { d ->
                val a = Offset(cx + d.x * w * .3f, cy + d.y * h * .3f); val b = Offset(cx + d.x * w * .42f, cy + d.y * h * .42f)
                drawLine(cob, a, b, 2f * u, StrokeCap.Round)
            }
        }
    }
}

/** Asked once for a new piece: "Devorga" or "Xonaning o‘rtasiga (erkin)", each with its picture. */
@Composable
fun WhereAsk(name: String, size: String, onBack: () -> Unit, onPick: (Boolean) -> Unit) {
    Box(Modifier.fillMaxSize().background(Color(0x6B0F172A)).clickable(remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, null) {})
    Box(Modifier.fillMaxSize().padding(horizontal = 12.dp, vertical = 16.dp), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().shadow(24.dp, RoundedCornerShape(28.dp)).clip(RoundedCornerShape(28.dp)).background(G.solid)
            .clickable(remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, null) {}.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(Color(0xFFB7895B)), contentAlignment = Alignment.Center) { ReIcon("sofa", Color.White, 20.dp) }
                Column(Modifier.weight(1f)) {
                    Text("$name · $size", style = ui(16f, 800, G.ink, 1.2f), maxLines = 2)
                    Text(tr("fp.pl.whereSub"), style = ui(12f, 500, G.ink2, 1.3f))
                }
                RoundX("close", tr("common.cancel"), onBack)
            }
            Row(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(true, false).forEach { wall ->
                    val shape = RoundedCornerShape(18.dp)
                    Column(Modifier.weight(1f).fillMaxHeight().clip(shape).background(G.ink.copy(alpha = .06f)).border(1.dp, G.rim, shape)
                        .clickable(role = Role.Button) { onPick(wall) }.padding(6.dp)) {
                        Box(Modifier.fillMaxWidth().height(78.dp).clip(RoundedCornerShape(13.dp)).background(RP.elev)) { WhereThumb(wall, Modifier.fillMaxSize()) }
                        Text(tr(if (wall) "fp.pl.wall" else "fp.pl.mid"), style = ui(13.5f, 800, G.ink, 1.2f), modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp))
                        Text(tr(if (wall) "fp.pl.wallSub" else "fp.pl.midSub"), style = ui(11.5f, 500, G.ink2, 1.3f), modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 2.dp, bottom = 2.dp))
                    }
                }
            }
            Box(Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f)).border(1.dp, G.rim, RoundedCornerShape(16.dp))
                .clickable(role = Role.Button, onClick = onBack), contentAlignment = Alignment.Center) { Text(tr("re.back"), style = ui(13.5f, 700)) }
        }
    }
}
