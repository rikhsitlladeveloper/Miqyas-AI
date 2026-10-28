package uz.metrx.app.ui.rooms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.rememberTextMeasurer
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.geo.DOOR_H
import uz.metrx.app.geo.DOOR_W
import uz.metrx.app.geo.SILLS
import uz.metrx.app.geo.WALL_MAX
import uz.metrx.app.geo.WALL_MIN
import uz.metrx.app.geo.WIN_H
import uz.metrx.app.geo.WIN_W
import uz.metrx.app.geo.distsOf
import uz.metrx.app.geo.magnet
import uz.metrx.app.geo.styleId
import uz.metrx.app.geo.thickOf
import uz.metrx.app.geo.z0Of
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.furniture.Bubble
import uz.metrx.app.ui.furniture.PressRing
import uz.metrx.app.ui.editor.english
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.ux.Hap
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * The room editor v2's canvas: the plan, the selected wall's front view or the simple 3D, with the mockup's gestures.
 * In the room flow's openings step a finger on an item slides it at once along its wall (no zoom). In the editor a
 * 0.4 s hold lifts it (a blue ring fills), a quick drag pans, two fingers zoom, a double tap fits. Magnets at the
 * corners and the middle; the front view's edges drag the size; the two live distances are tappable.
 */

/** The canvas's newest geometry, read by its gestures and by the icon row's drag. */
class ReGeo {
    var fit: PlanFit? = null
    var ff: FrontFit? = null
    var recs: List<ItemRec> = emptyList()
    var frecs: List<FrontRec> = emptyList()
    var hits: MutableList<IsoHit> = ArrayList()
    var bounds: Rect = Rect.Zero
    var view: String = "plan"
}

/** Keeps a value inside the room's wall: an opening's off from 0 to L − w, a point's from 0 to L. */
private fun withItem(r: Room, id: String, f: (Any) -> Any): Room =
    r.copy(openings = r.openings.map { if (it.id == id) f(it) as Opening else it }, points = r.points.map { if (it.id == id) f(it) as SitePoint else it })

/** The keypad for a field of the selection or the wall (the mockup's kpOpen). */
fun App.openKp(s: ReSession, field: String) {
    val r = s.room ?: return
    val o = s.selOp; val p = s.selPt
    val wall = o?.wall ?: p?.wall
    s.kp = when (field) {
        "dl", "dr" -> { if (wall == null) return
            val L = wallL(r, wall); val w = o?.w ?: 0; val hi = max(0, L - w); val (ln, rn) = neighbours(r, wall); val nb = if (field == "dl") ln else rn
            val cur = if (field == "dl") (o?.off ?: p!!.off) else hi - (o?.off ?: p!!.off)
            Kp(t(if (o != null) "re.kpDistOp" else "re.kpDistPt", "n" to kindName(o?.type ?: p!!.t), "w" to nb), cur, 0, hi) { v ->
                setDist(s, if (field == "dl") v else hi - v, t("re.distSet", "n" to kindName(o?.type ?: p!!.t), "w" to nb, "v" to mm(v))) } }
        "w" -> { if (o == null) return; Kp(t("re.kpW", "n" to kindName(o.type)), o.w, 300, wallL(r, o.wall)) { setW(s, it) } }
        "h" -> { if (o == null) return; Kp(t("re.kpH", "n" to kindName(o.type)), o.h, 300, wallH(r, o.wall) - z0Of(o)) { setH(s, it) } }
        "sill" -> { if (o == null) return; Kp(t("re.kpSill"), o.sill, 0, wallH(r, o.wall) - o.h) { setSill(s, it) } }
        "ph" -> { if (p == null) return; Kp(t("re.kpPh", "n" to kindName(p.t)), p.h, 0, wallH(r, p.wall)) { setPh(s, it) } }
        "wl" -> { val id = s.selWall ?: return; Kp(t("re.kpWall", "w" to id), wallL(r, id), WALL_MIN, WALL_MAX, big = true) { setWallLen(s, id, it) } }
        "thick" -> { val id = s.selWall ?: return; Kp(t("re.kpThick", "w" to id), thickOf(r, id), 50, 1000) { setThick(s, id, it) } }
        "rh" -> Kp(t("re.kpRh"), roomH(r), 2000, 6000) { setRoomH(s, it) }
        "diag" -> { val id = s.selWall ?: return; diagKp(s, r, id) ?: return }
        else -> iwKp(s, field) ?: return
    }
}

/** Burchak → "Diagonal bilan tekshirish": the wall's start to the next wall's end, against the plan's. */
private fun App.diagKp(s: ReSession, r: Room, id: String): Kp? {
    val ws = reWalls(r, reSnap()); val i = ws.indexOfFirst { it.id == id }; if (i < 0) return null
    val n = ws.size; val a = ws[i]; val b = ws[(i + 1) % n]
    val dd = hypot(b.b.x - a.a.x, b.b.y - a.a.y).roundToInt()
    return Kp(t("re.kpDiag", "a" to a.id, "b" to b.id), dd, WALL_MIN, WALL_MAX) { v ->
        if (abs(v - dd) <= max(20.0, dd * .005)) { haptic(Hap.CONFIRM); toast = uz.metrx.app.ui.components.ToastMsg(t("re.diagOk", "a" to cornerAngle(ws, (i + 1) % n), "v" to mm(v))) }
        else {
            val la = a.L.toDouble(); val lb = b.L.toDouble()
            val cs = ((la * la + lb * lb - v.toDouble() * v) / (2 * la * lb)).coerceIn(-1.0, 1.0)
            val ang = String.format(java.util.Locale.ROOT, "%.1f", Math.toDegrees(kotlin.math.acos(cs))).replace('.', if (english()) '.' else ',')
            haptic(Hap.WARN); toast = uz.metrx.app.ui.components.ToastMsg(t("re.diagBad", "a" to ang), uz.metrx.app.ui.components.ToastKind.ERROR)
        }
    }
}

/** The inside angle at the start of wall [i], degrees (Burchak). */
fun cornerAngle(ws: List<RW>, i: Int): Int {
    val n = ws.size; val a = ws[(i - 1 + n) % n]; val b = ws[i]
    val ux = a.b.x - a.a.x; val uy = a.b.y - a.a.y; val vx = b.b.x - b.a.x; val vy = b.b.y - b.a.y
    val turn = Math.toDegrees(kotlin.math.atan2(ux * vy - uy * vx, ux * vx + uy * vy))
    var ar = 0.0; for (k in 0 until n) { val p = ws[k].a; val q = ws[(k + 1) % n].a; ar += p.x * q.y - q.x * p.y }
    return (180 - turn * (if (ar >= 0) 1 else -1)).roundToInt()
}

/**
 * The canvas. [box] is where the drawing goes inside it (the hint and caption above take [top] px); [avoid] px at the
 * bottom are under the floating card (the openings step pans the plan so the selected item stays visible).
 */
@Composable
fun ReCanvas(s: ReSession, geo: ReGeo, modifier: Modifier, top: Float = 0f, avoid: Float = 0f, pills: Boolean = true, overlay: @Composable BoxScope.() -> Unit = {}) {
    val app = LocalApp.current
    val r = s.room ?: return
    val d = LocalDensity.current
    val u = d.density
    val tm = rememberTextMeasurer()
    val view = if (s.inFlow) "plan" else s.view
    val zoom = s.zooms[view]!!
    var pan by remember { mutableStateOf(0f) }
    var ring by remember { mutableStateOf<Offset?>(null) }
    val ws = reWalls(r, app.reSnap())
    val bad = app.issuesOf(r).map { it.id }.toSet()
    val selItem = (s.sel as? ReSel.Item)?.id
    BoxWithConstraints(modifier.onGloballyPositioned { geo.bounds = it.boundsInRoot() }) {
        val W = constraints.maxWidth.toFloat(); val H = constraints.maxHeight.toFloat()
        val small = s.inFlow
        geo.view = view
        // the fingers first, under the bubbles and chips drawn on top (those take their own taps)
        Box(Modifier.fillMaxSize().pointerInput(s.inFlow) { gestures(app, s, geo, { ring = it }) })
        // the ghost: the icon row's drag, or the pick's item on its wall while its window is open
        val ghost: Any? = s.ghost?.it ?: s.pk?.takeIf { it.mode == "new" }?.let { app.pkBuild(s, it) }
        val ghostWall = when (ghost) { is Opening -> ghost.wall; is SitePoint -> ghost.wall; else -> null }
        when (view) {
            "front" -> {
                val L = app.wallL(r, s.fw)
                val ff = frontFit(s.fw, L, app.wallH(r, s.fw), Rect(0f, top, W, H - 54 * u), false, zoom.z, zoom.ox, zoom.oy, u)
                geo.ff = ff; geo.frecs = frontRecs(r, ff, u); geo.fit = null
                val nb = app.neighbours(r, s.fw)
                val cap = app.t("re.frontCap", "w" to app.wLab(r, s.fw), "l" to mm(L), "h" to mm(app.wallH(r, s.fw)))
                Canvas(Modifier.fillMaxSize()) { drawFront(r, ff, selItem, s.selWall == s.fw, if (ghostWall == s.fw) ghost else null, bad, nb, cap, tm, u) }
                if (pills && s.pk == null && s.ghost == null) FrontPills(s, r, ff, u)
            }
            "3d" -> {
                geo.fit = null; geo.ff = null
                Canvas(Modifier.fillMaxSize()) { drawIso(r, ws, top, zoom, selItem, s.selWall, bad, tm, u, geo.hits, (s.sel as? ReSel.Piece)?.id) }
            }
            else -> {
                val box = Rect(0f, top, W, H)
                val padX = 40 * u
                // the openings step: the plan moves up so the selected item stays above the floating card (still while a finger drags)
                if (s.inFlow) {
                    val sel = selItem?.let { id -> r.openings.firstOrNull { it.id == id } ?: r.points.firstOrNull { it.id == id } }
                    if (sel != null && avoid > 0 && s.live == null) {
                        val f0 = planFit(r, ws, box, 26 * u, padX)
                        val rec = f0?.let { planRec(it, sel, true, u) }
                        if (rec != null) {
                            val yb = if (rec.op) maxOf(rec.p0.y, rec.p1.y, rec.q0.y, rec.q1.y) else rec.c.y + 10 * u
                            val yc = if (rec.op) (rec.p0.y + rec.p1.y + rec.q0.y + rec.q1.y) / 4 else rec.c.y
                            val lim = H - avoid - 34 * u
                            pan = if (yb > lim) min(0f, max(lim - yb, (top + lim) / 2 - yc)) else 0f
                        }
                    } else if (s.selPieceOnly != null && avoid > 0 && s.live == null) {
                        // a selected inner wall too stays above the card
                        val f0 = planFit(r, ws, box, 26 * u, padX)
                        val pts = f0?.let { f -> uz.metrx.app.geo.pieceGeo(s.selPieceOnly!!, roomH(r)).R.flatten().map { f.M(uz.metrx.app.data.Pt(it.x, it.y)) } }
                        if (pts != null && pts.isNotEmpty()) {
                            val yb = pts.maxOf { it.y } + 30 * u; val yc = (pts.minOf { it.y } + pts.maxOf { it.y }) / 2
                            val lim = H - avoid - 34 * u
                            pan = if (yb > lim) min(0f, max(lim - yb, (top + lim) / 2 - yc)) else 0f
                        }
                    } else if (sel == null && s.selPieceOnly == null) pan = 0f
                }
                val fit = if (s.inFlow) planFit(r, ws, box, 26 * u, padX, 1f, 0f, pan) else planFit(r, ws, Rect(0f, top, W, H - 6 * u), 36 * u, 62 * u, zoom.z, zoom.ox, zoom.oy)
                geo.fit = fit; geo.ff = null
                if (fit != null) {
                    geo.recs = (r.openings + r.points).mapNotNull { planRec(fit, it, small, u) }
                    val magMid = s.mag?.takeIf { it.second == "mid" }?.let { m -> r.openings.firstOrNull { it.id == m.first }?.wall ?: r.points.firstOrNull { it.id == m.first }?.wall ?: ghostWall }
                    val look = PlanLook2(selItem = selItem, selWall = s.selWall, hl = ghostWall, arm = s.arm != null, ghost = ghost, magMid = magMid, lens = s.dLen,
                        chain = !s.inFlow && s.dChain, areaText = if (!s.inFlow && s.dArea) app.areaLine(r) else null, small = small, bad = bad,
                        selPiece = (s.sel as? ReSel.Piece)?.id, ghostPiece = s.ghostId, magWalls = s.iwMag?.outer?.toSet() ?: emptySet(), magPieces = s.iwMag?.pieces?.toSet() ?: emptySet())
                    val lens = app.wallLens(r)
                    Canvas(Modifier.fillMaxSize()) { drawPlanV2(r, fit, look, tm, u) { id -> mm(lens[id] ?: 0) } }
                    if (pills) {
                        val target = if (s.ghost?.it != null) s.ghost?.it else if (s.pk == null) selItem?.let { id -> r.openings.firstOrNull { it.id == id } ?: r.points.firstOrNull { it.id == id } } else null
                        if (target != null) PlanPills(s, r, fit, target, live = s.ghost == null, u = u)
                        val pc = s.selPieceOnly
                        if (pc != null && s.pk == null && s.ghost == null) IwPills(s, r, fit, pc, u)
                    }
                }
            }
        }
        PressRingAt(ring)
        overlay()
        // gestures
    }
}

@Composable
private fun BoxScope.PressRingAt(at: Offset?) { PressRing(at) }

/** "8,8 m² · perimetr 12 000" in the plan's middle (O‘lchamlar → Maydon). */
fun App.areaLine(r: Room): String {
    val a = uz.metrx.app.geo.areas(r, reSnap()) ?: return ""
    return uz.metrx.app.geo.fmtArea(a.floor, english()) + " m² · " + t("re.perim", "v" to mm(a.perim.toInt()))
}

/** The two live distances to the corners of the selected (or dragged) item, as blue lines and tappable bubbles. */
@Composable
private fun BoxScope.PlanPills(s: ReSession, r: Room, fit: PlanFit, it: Any, live: Boolean, u: Float) {
    val app = LocalApp.current
    val rec = planRec(fit, it, s.inFlow, u) ?: return
    val f = rec.f
    val o = (if (s.inFlow) 21f else 24f) * u
    fun off(p: Offset) = Offset(p.x + f.n.x * o, p.y + f.n.y * o)
    val A = off(f.a); val B = off(f.b); val s0 = off(if (rec.op) rec.p0 else rec.w0); val s1 = off(if (rec.op) rec.p1 else rec.w0)
    val cob = G.cobalt
    Canvas(Modifier.fillMaxSize()) {
        drawLine(cob, A, s0, 1.3f * u); drawLine(cob, s1, B, 1.3f * u)
        listOf(A, s0, s1, B).forEach { p -> drawLine(cob, Offset(p.x - f.n.x * 5 * u, p.y - f.n.y * 5 * u), Offset(p.x + f.n.x * 5 * u, p.y + f.n.y * 5 * u), 1.6f * u, StrokeCap.Butt) }
    }
    val L = app.wallL(r, f.id)
    val dd = when (it) { is Opening -> distsOf(it, L); is SitePoint -> distsOf(it, L); else -> return }
    val m1 = Offset((A.x + s0.x) / 2, (A.y + s0.y) / 2); val m2 = Offset((s1.x + B.x) / 2, (s1.y + B.y) / 2)
    val magged = s.mag?.first == (it as? Opening)?.id ?: (it as? SitePoint)?.id
    ReBubble(mm(dd.left), m1.x, m1.y, live = magged, small = !live, onClick = if (live) ({ app.openKp(s, "dl") }) else null)
    ReBubble(mm(dd.right), m2.x, m2.y, live = magged, small = !live, onClick = if (live) ({ app.openKp(s, "dr") }) else null)
    s.mag?.let { m ->
        val c = if (rec.op) Offset((rec.p0.x + rec.p1.x) / 2, (rec.p0.y + rec.p1.y) / 2) else rec.c
        val p = Offset(c.x + f.n.x * (if (rec.op) 46 else 40) * u, c.y + f.n.y * (if (rec.op) 46 else 40) * u)
        ReBubble(app.t("re.mag", "a" to app.t(if (m.second == "mid") "re.magMid" else "re.magCorner")), p.x, p.y, live = true, small = true)
    }
}

/** The front view's bubbles: width, height, sill (or a point's height), and the two corner distances. */
@Composable
private fun BoxScope.FrontPills(s: ReSession, r: Room, ff: FrontFit, u: Float) {
    val app = LocalApp.current
    val id = (s.sel as? ReSel.Item)?.id ?: return
    val o = r.openings.firstOrNull { it.id == id && it.wall == ff.wall }
    val p = r.points.firstOrNull { it.id == id && it.wall == ff.wall }
    if (o == null && p == null) return
    val yf = ff.Z(0.0)
    if (o != null) {
        val xl = min(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble())); val xr = max(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble()))
        val yt = ff.Z(opTop(o).toDouble()); val yb = ff.Z(z0Of(o).toDouble()); val xc = (xl + xr) / 2; val ym = (yt + yb) / 2
        val offx = 54 * u; var hx = xr + offx; if (hx > ff.X(ff.L.toDouble()) + 40 * u) hx = xl - offx
        ReBubble(app.t("re.f.w").lowercase() + " " + mm(o.w), xc, yt - 22 * u, onClick = { app.openKp(s, "w") })
        ReBubble(app.t("re.f.h").lowercase() + " " + mm(o.h), hx, ym, onClick = { app.openKp(s, "h") })
        if (o.type == "window" && styleId(o) != "pano" && styleId(o) != "balcony") ReBubble(app.t("re.f.sill").lowercase() + " " + mm(o.sill), if (hx > xr) xl - offx else xr + offx, (yb + yf) / 2, onClick = { app.openKp(s, "sill") })
        val L = app.wallL(r, o.wall); val dd = distsOf(o, L)
        ReBubble(mm(dd.left), (ff.X(0.0) + xl) / 2, yf + 15 * u, onClick = { app.openKp(s, "dl") })
        ReBubble(mm(dd.right), (xr + ff.X(ff.L.toDouble())) / 2, yf + 15 * u, onClick = { app.openKp(s, "dr") })
    } else if (p != null) {
        val x = ff.X(p.off.toDouble()); val y = ff.Z(p.h.toDouble())
        ReBubble("h " + mm(p.h), x + 52 * u, y, onClick = { app.openKp(s, "ph") })
        val L = app.wallL(r, p.wall); val dd = distsOf(p, L)
        ReBubble(mm(dd.left), (ff.X(0.0) + x) / 2, yf + 15 * u, onClick = { app.openKp(s, "dl") })
        ReBubble(mm(dd.right), (x + ff.X(ff.L.toDouble())) / 2, yf + 15 * u, onClick = { app.openKp(s, "dr") })
    }
}

/* ---------------- gestures ---------------- */

private const val LIFT = 400L

private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.gestures(app: App, s: ReSession, geo: ReGeo, ring: (Offset?) -> Unit) {
    var lastTap = 0L; var lastTapAt = Offset.Zero
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val u = density
        if (s.pk != null || s.kp != null || s.iwWin) return@awaitEachGesture
        val p0 = down.position
        val zoom = s.zooms[geo.view]!!
        val zx0 = zoom.ox; val zy0 = zoom.oy
        val flow = s.inFlow
        // what is under the finger
        var mode = "tap"; var itemId: String? = null; var edge: String? = null; var pieceId: String? = null
        var iwR0: uz.metrx.app.data.Pt? = null; var iwBase: uz.metrx.app.data.InnerWall? = null; var iwStr = false
        val snap = s.room
        if (s.arm == null) when (geo.view) {
            "front" -> { val ff = geo.ff
                val so = s.selOp
                if (ff != null && so != null && so.wall == ff.wall) edge = frontHandles(so, ff).minByOrNull { hypot(it.c.x - p0.x, it.c.y - p0.y) }?.takeIf { hypot(it.c.x - p0.x, it.c.y - p0.y) < 19 * u }?.e
                if (edge != null) { mode = "edge"; app.haptic(Hap.TICK) }
                else hitFront(geo.frecs, p0, u)?.let { itemId = it; mode = if (flow) "pressD" else "press" } }
            "plan" -> geo.fit?.let { fit ->
                hitPlan(geo.recs, p0, u)?.let { itemId = it; mode = if (flow) "pressD" else "press" }
                // an inner wall: in the openings step (or already selected) it moves at once, in the editor after a 0.4 s hold
                if (itemId == null) snap?.let { hitPiece(it, fit, p0, u) }?.let { pieceId = it; mode = if (flow || (s.sel as? ReSel.Piece)?.id == it) "iwD" else "iwPress" }
            }
        }
        if (mode == "press" || mode == "iwPress") ring(p0)
        var grab = 0.0; var hgrab = 0.0
        var changed = false
        fun startSlide(p: Offset) {
            val id = itemId ?: return
            mode = "slide"; ring(null)
            s.sel = ReSel.Item(id)
            val r = s.room ?: return
            val o = r.openings.firstOrNull { it.id == id }; val pt = r.points.firstOrNull { it.id == id }
            s.fw = o?.wall ?: pt?.wall ?: s.fw
            if (!flow && s.strip != null) s.strip = null
            val dist = (o?.off ?: pt?.off ?: 0).toDouble()
            if (geo.view == "front") { val ff = geo.ff ?: return; grab = ff.T(p.x) - dist; hgrab = if (pt != null) ff.Hh(p.y) - pt.h else 0.0 }
            else { val fit = geo.fit ?: return; val f = fit.frame(o?.wall ?: pt!!.wall) ?: return; grab = (segD(p, f.a, f.b).second / fit.k).toDouble() - dist }
            app.haptic(Hap.TICK)
        }
        fun slide(p: Offset) {
            val id = itemId ?: return; val base = snap ?: return
            val o = base.openings.firstOrNull { it.id == id }; val pt = base.points.firstOrNull { it.id == id }
            val wall = o?.wall ?: pt?.wall ?: return
            val L = app.wallL(base, wall)
            val raw: Double; val k: Float
            if (geo.view == "front") { val ff = geo.ff ?: return; raw = ff.T(p.x) - grab; k = ff.k }
            else { val fit = geo.fit ?: return; val f = fit.frame(wall) ?: return; raw = (segD(p, f.a, f.b).second / fit.k).toDouble() - grab; k = fit.k }
            val m = magnet(o?.w ?: 0, L, raw, (12 * u / k).toDouble())
            s.mag = m.at?.let { id to it }
            var nh: Int? = null
            if (geo.view == "front" && pt != null) {
                val ff = geo.ff!!; val hz = ff.Hh(p.y) - hgrab; val th = min(150.0, (12 * u / ff.k).toDouble())
                nh = ptSnaps(pt.t).filter { abs(hz - it) < th }.minByOrNull { abs(hz - it) } ?: (Math.round(hz / 10) * 10).toInt().coerceIn(0, roomH(base))
            }
            s.live = withItem(base, id) { x -> when (x) { is Opening -> x.copy(off = m.v); is SitePoint -> x.copy(off = m.v, h = nh ?: x.h); else -> x } }
            changed = true
        }
        fun startIw(p: Offset) {
            val id = pieceId ?: return; val fit = geo.fit ?: return; val base = snap ?: return
            mode = "iw"; ring(null)
            s.sel = ReSel.Piece(id); s.arm = null
            if (!flow && s.strip != null) s.strip = null
            iwR0 = fit.MI(p); iwBase = base.inner.firstOrNull { it.id == id }
            app.haptic(Hap.TICK)
        }
        fun doIw(p: Offset) {
            val fit = geo.fit ?: return; val base = snap ?: return; val b = iwBase ?: return; val r0 = iwR0 ?: return
            val q = fit.MI(p)
            val P = uz.metrx.app.geo.outline(base, app.reSnap())
            val nx = (b.x + (q.x - r0.x)).coerceIn(P.minOf { it.x }, P.maxOf { it.x }); val ny = (b.y + (q.y - r0.y)).coerceIn(P.minOf { it.y }, P.maxOf { it.y })
            val res = uz.metrx.app.geo.iwSnap(base, b.copy(x = Math.round(nx).toInt(), y = Math.round(ny).toInt()), app.reSnap())
            s.iwMag = res; iwStr = res.str
            s.live = base.copy(inner = base.inner.map { if (it.id == b.id) res.p else it })
            changed = true
        }
        fun doEdge(p: Offset) {
            val ff = geo.ff ?: return; val base = snap ?: return; val o = base.openings.firstOrNull { it.id == s.selOp?.id } ?: return
            val L = ff.L; val rh = ff.rh; val t = ff.T(p.x); val hz = ff.Hh(p.y)
            val cw = if (o.type == "door") DOOR_W else WIN_W; val ch = if (o.type == "door") DOOR_H else WIN_H
            val thr = (14 * u / ff.k).toDouble().coerceIn(20.0, 60.0)
            fun snapTo(v: Double, list: List<Int>): Int = list.filter { abs(v - it) < thr }.minByOrNull { abs(v - it) } ?: (Math.round(v / 10) * 10).toInt()
            var n = o
            when (edge) {
                "l" -> { val t1 = o.off + o.w; val w = snapTo(t1 - t.coerceIn(0.0, (t1 - 300).toDouble()), cw).coerceIn(300, t1); n = o.copy(w = w, off = t1 - w)
                    if (n.balcony && n.w < n.dw + 300) { val mw = n.dw + 300; n = n.copy(off = n.off + n.w - mw, w = mw) } }
                "r" -> { val w = snapTo(t.coerceIn((o.off + 300).toDouble(), L.toDouble()) - o.off, cw).coerceIn(300, max(300, L - o.off)); n = o.copy(w = w)
                    if (n.balcony && n.w < n.dw + 300) n = n.copy(w = n.dw + 300) }
                "t" -> { val z0 = z0Of(o); var h = snapTo(hz - z0, ch).coerceIn(300, max(300, rh - z0)); if (o.balcony) h = max(h, o.wh + 100); n = o.copy(h = h) }
                "b" -> { val top = o.sill + o.h; val ns = snapTo(hz.coerceIn(0.0, (top - 300).toDouble()), SILLS).coerceIn(0, max(0, top - 300)); n = o.copy(sill = ns, h = top - ns) }
            }
            s.live = base.copy(openings = base.openings.map { if (it.id == o.id) n else it })
            changed = true
        }
        var pinch: Triple<Float, Offset, Float>? = null
        while (true) {
            val ev = if (mode == "press" || mode == "iwPress") withTimeoutOrNull(LIFT - (currentEvent.changes.firstOrNull()?.uptimeMillis?.minus(down.uptimeMillis) ?: 0L).coerceIn(0, LIFT)) { awaitPointerEvent() }
                     else awaitPointerEvent()
            if (ev == null) { // held 0.4 s: lifted
                if (mode == "press") startSlide(p0) else if (mode == "iwPress") startIw(p0)
                continue
            }
            val pressed = ev.changes.filter { it.pressed }
            if (pressed.isEmpty()) break
            if (!flow && pressed.size >= 2) {
                // two fingers: zoom (a slide in progress goes back)
                if (mode == "slide" || mode == "edge" || mode == "iw") { s.live = null; s.mag = null; s.iwMag = null; changed = false }
                ring(null)
                val a = pressed[0].position; val b = pressed[1].position
                val dd = max(10f, hypot(a.x - b.x, a.y - b.y)); val m = Offset((a.x + b.x) / 2, (a.y + b.y) / 2)
                if (pinch == null) pinch = Triple(dd, m, zoom.z)
                else { val (d0, m0, z0) = pinch!!; val nz = (z0 * dd / d0).coerceIn(.6f, 6f)
                    zoom.ox = m.x - (m0.x - zx0) * (nz / z0); zoom.oy = m.y - (m0.y - zy0) * (nz / z0); zoom.z = nz }
                mode = "pinch"
                ev.changes.forEach { it.consume() }
                continue
            }
            val c = ev.changes.firstOrNull { it.id == down.id } ?: continue
            val p = c.position; val hyp = hypot(p.x - p0.x, p.y - p0.y)
            when (mode) {
                "edge" -> { doEdge(p); c.consume() }
                "slide" -> { slide(p); c.consume() }
                "pressD" -> if (hyp > 5 * u) { startSlide(p); slide(p); c.consume() }
                "iw" -> { doIw(p); c.consume() }
                "iwD" -> if (hyp > 5 * u) { startIw(p); doIw(p); c.consume() }
                "press", "iwPress" -> if (hyp > 8 * u) { ring(null); mode = "pan" }
                "tap" -> if (hyp > 8 * u) mode = if (flow) "none" else "pan"
            }
            if (mode == "pan") { zoom.ox = zx0 + (p.x - p0.x); zoom.oy = zy0 + (p.y - p0.y); c.consume() }
        }
        ring(null)
        when (mode) {
            "iw" -> {
                val base = snap ?: return@awaitEachGesture
                s.iwMag = null
                val r1 = s.live
                if (!changed || r1 == null) { s.live = null; return@awaitEachGesture }
                val p1 = r1.inner.firstOrNull { it.id == pieceId } ?: run { s.live = null; return@awaitEachGesture }
                s.live = app.clampItems(uz.metrx.app.geo.syncFaces(r1, app.reSnap()))
                s.ghostId = null
                s.endLive(app, base, app.t("iw.moved", "n" to app.iwName(p1.k), "v" to (mm(p1.len) + if (p1.len2 > 0 && (p1.k == "L" || p1.k == "T")) " + " + mm(p1.len2) else "")) +
                    if (iwStr) " · " + app.t("iw.str") else "")
            }
            "slide", "edge" -> {
                val base = snap ?: return@awaitEachGesture
                s.mag = null
                if (!changed || s.live == null) { s.live = null; return@awaitEachGesture }
                val r1 = s.live!!
                val id = itemId ?: s.selOp?.id
                val o = r1.openings.firstOrNull { it.id == id }; val pt = r1.points.firstOrNull { it.id == id }
                val msg = if (mode == "edge" && o != null) app.t("re.edgeCh", "n" to app.kindName(o.type), "v" to app.sizeLine(o))
                else { val L = app.wallL(r1, o?.wall ?: pt?.wall ?: ""); val dd = if (o != null) distsOf(o, L) else distsOf(pt!!, L)
                    app.t("re.moved", "n" to app.kindName(o?.type ?: pt!!.t), "a" to mm(dd.left), "b" to mm(dd.right)) + (pt?.let { " · h " + mm(it.h) } ?: "") }
                s.endLive(app, base, msg)
            }
            "tap", "press", "pressD", "iwPress", "iwD" -> {
                val now = System.currentTimeMillis()
                if (!flow && now - lastTap < 320 && hypot(p0.x - lastTapAt.x, p0.y - lastTapAt.y) < 26 * u) { zoom.reset(); lastTap = 0L; return@awaitEachGesture }
                lastTap = now; lastTapAt = p0
                tap(app, s, geo, p0, u)
            }
        }
    }
}

private fun tap(app: App, s: ReSession, geo: ReGeo, p: Offset, u: Float) {
    val r = s.room ?: return
    val arm = s.arm
    when (geo.view) {
        "3d" -> {
            val h = hitIso(geo.hits, p)
            if (arm != null) { if (h != null && h.wall) app.placeAt(s, arm, h.id, app.wallL(r, h.id) / 2.0, "tap") else app.say("re.tapWallT", kind = uz.metrx.app.ui.components.ToastKind.ERROR); return }
            if (h == null) deselect(s) else if (h.wall) selectWall(app, s, h.id) else if (h.id.startsWith("piece:")) selectPiece(app, s, h.id.removePrefix("piece:")) else selectItem(app, s, h.id)
        }
        "front" -> {
            val ff = geo.ff ?: return
            val inWall = p.x >= min(ff.X(0.0), ff.X(ff.L.toDouble())) - 6 * u && p.x <= max(ff.X(0.0), ff.X(ff.L.toDouble())) + 6 * u && p.y >= ff.Z(ff.rh.toDouble()) - 6 * u && p.y <= ff.Z(0.0) + 6 * u
            if (arm != null && inWall) { app.placeAt(s, arm, ff.wall, ff.T(p.x).coerceIn(0.0, ff.L.toDouble()), "tap"); return }
            val hit = hitFront(geo.frecs, p, u)
            if (hit != null) selectItem(app, s, hit) else if (inWall) selectWall(app, s, ff.wall) else deselect(s)
        }
        else -> {
            val fit = geo.fit ?: return
            if (arm != null) {
                val w = nearWall(fit, p, 44 * u)
                if (w != null) {
                    val L = app.wallL(r, w.first.id)
                    var it = app.mkItem(r, arm, w.first.id, w.second)
                    it = when (it) { is Opening -> it.copy(off = magnet(it.w, L, it.off.toDouble(), (12 * u / fit.k).toDouble()).v); is SitePoint -> it.copy(off = magnet(0, L, it.off.toDouble(), (12 * u / fit.k).toDouble()).v); else -> it }
                    app.beginPlace(s, it, "tap"); return
                }
                app.haptic(Hap.WARN); app.say("re.tapWall", kind = uz.metrx.app.ui.components.ToastKind.ERROR); return
            }
            hitPlan(geo.recs, p, u)?.let { selectItem(app, s, it); return }
            // an inner wall: the first tap the piece, a second its nearest face
            hitPiece(r, fit, p, u)?.let { id ->
                if ((s.sel as? ReSel.Piece)?.id == id) faceAt(fit, r, id, p)?.let { selectWall(app, s, it); return }
                selectPiece(app, s, id); return
            }
            nearWall(fit, p, 24 * u)?.let { selectWall(app, s, it.first.id); return }
            deselect(s)
        }
    }
}

fun selectItem(app: App, s: ReSession, id: String) {
    val r = s.room ?: return
    val w = r.openings.firstOrNull { it.id == id }?.wall ?: r.points.firstOrNull { it.id == id }?.wall ?: return
    s.sel = ReSel.Item(id); s.arm = null; s.fw = w
    if (!s.inFlow) s.strip = null
    app.haptic(Hap.TICK)
}

fun selectWall(app: App, s: ReSession, id: String) {
    if (s.inFlow && s.selWall == id) { deselect(s); return }
    s.sel = ReSel.Wall(id); s.fw = id; s.arm = null
    if (!s.inFlow) s.strip = null
    app.haptic(Hap.TICK)
}

fun deselect(s: ReSession) { s.sel = null; s.strip = null; s.arm = null }

/** The plan without fingers (the summary): the room with its doors, windows and points. */
@Composable
fun RoomPlanStatic(r: Room, modifier: Modifier) {
    val app = LocalApp.current
    val u = LocalDensity.current.density
    val tm = rememberTextMeasurer()
    val ws = reWalls(r, app.reSnap())
    val lens = app.wallLens(r)
    val bad = app.issuesOf(r).map { it.id }.toSet()
    Canvas(modifier) {
        val fit = planFit(r, ws, Rect(0f, 0f, size.width, size.height), 26 * u, 40 * u) ?: return@Canvas
        drawPlanV2(r, fit, PlanLook2(small = true, bad = bad), tm, u) { id -> mm(lens[id] ?: 0) }
    }
}

/**
 * Where an icon dragged from the row would land: the item it makes on the nearest wall (plan: within 90 px; front
 * view: inside the wall, a point at the nearest usual height) and its magnet, or null off the walls. [root] is the
 * finger in root px.
 */
fun App.dropTarget(s: ReSession, geo: ReGeo, kind: String, root: Offset): Pair<Any, String?>? {
    val r = s.room ?: return null
    val b = geo.bounds
    if (!b.contains(root)) return null
    val p = Offset(root.x - b.left, root.y - b.top)
    val u = ctx.resources.displayMetrics.density
    if (geo.view == "front") {
        val ff = geo.ff ?: return null
        if (p.x < min(ff.X(0.0), ff.X(ff.L.toDouble())) || p.x > max(ff.X(0.0), ff.X(ff.L.toDouble())) || p.y < ff.Z(ff.rh.toDouble()) || p.y > ff.Z(0.0)) return null
        var it = mkItem(r, kind, ff.wall, ff.T(p.x))
        val L = ff.L
        it = when (it) {
            is Opening -> { val m = magnet(it.w, L, it.off.toDouble(), (12 * u / ff.k).toDouble()); return it.copy(off = m.v) to m.at }
            is SitePoint -> { val m = magnet(0, L, it.off.toDouble(), (12 * u / ff.k).toDouble()); val hz = ff.Hh(p.y)
                val best = ptSnaps(kind).minByOrNull { abs(hz - it) } ?: it.h
                return it.copy(off = m.v, h = if (abs(hz - best) < 150) best else (Math.round(hz / 10) * 10).toInt().coerceIn(0, roomH(r))) to m.at }
            else -> it
        }
        return null
    }
    if (geo.view == "3d") return null
    val fit = geo.fit ?: return null
    val w = nearWall(fit, p, 90 * u) ?: return null
    val L = wallL(r, w.first.id)
    val it = mkItem(r, kind, w.first.id, w.second)
    return when (it) {
        is Opening -> { val m = magnet(it.w, L, it.off.toDouble(), (12 * u / fit.k).toDouble()); it.copy(off = m.v) to m.at }
        is SitePoint -> { val m = magnet(0, L, it.off.toDouble(), (12 * u / fit.k).toDouble()); it.copy(off = m.v) to m.at }
        else -> null
    }
}
