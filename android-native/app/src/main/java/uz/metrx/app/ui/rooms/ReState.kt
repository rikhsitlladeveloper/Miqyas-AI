package uz.metrx.app.ui.rooms

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.pointDefaults
import uz.metrx.app.data.uid
import uz.metrx.app.geo.POINT_HS
import uz.metrx.app.geo.ROOM_HS
import uz.metrx.app.geo.ReIssue
import uz.metrx.app.geo.RoomShape
import uz.metrx.app.geo.ShapeSpec
import uz.metrx.app.geo.WALL_MAX
import uz.metrx.app.geo.WALL_MIN
import uz.metrx.app.geo.applyVals
import uz.metrx.app.geo.bigWall
import uz.metrx.app.geo.checkAll
import uz.metrx.app.geo.distsOf
import uz.metrx.app.geo.freeSpot
import uz.metrx.app.geo.isOpenKind
import uz.metrx.app.geo.magnet
import uz.metrx.app.geo.mirrorRoom
import uz.metrx.app.geo.overlaps
import uz.metrx.app.geo.pkSteps
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.geo.roomIssues
import uz.metrx.app.geo.shapeToRoom
import uz.metrx.app.geo.stdVals
import uz.metrx.app.geo.styleId
import uz.metrx.app.geo.styleOf
import uz.metrx.app.geo.thickOf
import uz.metrx.app.geo.topOf
import uz.metrx.app.geo.valsOf
import uz.metrx.app.geo.walls
import uz.metrx.app.geo.z0Of
import uz.metrx.app.ui.App
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.ux.Hap
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * The room editor v2's state and actions, shared by the room flow's openings step and the room editor of every trade
 * (mockup design/room-editor/mockup.html): the selection, the icon armed, the drag's ghost, the style window and the
 * size steps ([Pick]), undo and redo with "Ortga qaytarish" toasts, and every change made to the room's doors, windows,
 * points, walls and shape. A session lives outside the screens ([ReSessions]), so the laser radar or a sheet on top of
 * it loses nothing.
 */

/** What is selected: a wall (by id: an outer wall or an inner face), an item (an opening's or a point's id) or an inner wall (its piece). */
sealed interface ReSel {
    data class Wall(val id: String) : ReSel
    data class Item(val id: String) : ReSel
    data class Piece(val id: String) : ReSel
}

/**
 * A wall as the canvases take it: its id, ends (plan mm, clockwise) and length; an inner wall's face has [face] (its
 * piece, side and height).
 */
data class RW(val id: String, val a: Pt, val b: Pt, val L: Int, val face: uz.metrx.app.geo.InFace? = null) {
    val inner get() = face != null
}

/** The outer walls (the room's outline). */
fun reWalls(r: Room, snap: Boolean): List<RW> = walls(r, snap).map { w ->
    RW(w.id, w.p0, w.p1, w.len ?: hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y).roundToInt())
}

/** The outer walls, then the inner walls' faces (lettered after them). */
fun reAll(r: Room, snap: Boolean): List<RW> = reWalls(r, snap) + uz.metrx.app.geo.innerFaces(r, snap).map { f -> RW(f.id, Pt(f.a.x, f.a.y), Pt(f.b.x, f.b.y), f.len, f) }

/**
 * The style window and the size steps for one item: [mode] "new" (a ghost on the wall), "retype" (Turi) or "resize"
 * (O‘lcham); [how] it came (drag, tap, chip); [center] where it sits along [wall] (mm); [base] the new item or the one
 * changed (an [Opening] or a [SitePoint]); [style] null until picked; [v] the sizes by field; [step] the size asked.
 */
data class Pick(
    val mode: String, val how: String, val kind: String, val wall: String, val center: Double, val id: String?, val base: Any,
    val phase: String, val style: String?, val v: Map<String, Int> = emptyMap(), val step: Int = 0, val note: String? = null,
    val again: Boolean = false, val ph0: Int? = null, val flash: Int = 0
)

/** The number keypad over the screen: [lab] what is typed, [cur] the value now, the range, [big] a wall (the 30 m note). */
class Kp(val lab: String, val cur: Int, val lo: Int, val hi: Int, val big: Boolean = false, val ok: (Int) -> Unit) {
    var v by mutableStateOf("")
    var err by mutableStateOf<String?>(null)
    var note by mutableStateOf<String?>(null)
}

/** The view's zoom and pan (the editor's plan, front view and 3D each keep their own). */
class Zoom { var z by mutableStateOf(1f); var ox by mutableStateOf(0f); var oy by mutableStateOf(0f)
    fun reset() { z = 1f; ox = 0f; oy = 0f }
    val moved get() = z != 1f || ox != 0f || oy != 0f
}

/** A drag from the icon row: the [kind], the item it would make where the finger is ([it] null: off the walls). */
data class Ghost(val kind: String, val x: Float, val y: Float, val it: Any? = null, val mag: String? = null)

/**
 * One editing session of a room. [inFlow]: the room flow's openings step (items drag at once, no zoom) rather than the
 * editor; [read] gives the room as saved, [write] saves a change; [trade] orders the icon row.
 */
class ReSession(val key: String, val trade: String, val inFlow: Boolean, val pid: String, val rid: String?,
                private val read: () -> Room?, private val write: (Room) -> Unit) {
    /** The room while a finger slides an item (not saved until it lifts). */
    var live by mutableStateOf<Room?>(null)
    val room: Room? get() = live ?: read()

    var sel by mutableStateOf<ReSel?>(null)
    var arm by mutableStateOf<String?>(null)
    var pk by mutableStateOf<Pick?>(null)
    var ghost by mutableStateOf<Ghost?>(null)
    var mag by mutableStateOf<Pair<String, String>?>(null)
    var cardMin by mutableStateOf(false)
    var strip by mutableStateOf<String?>(null)
    var view by mutableStateOf("plan")
    var last2d = "plan"
    var fw by mutableStateOf("A")
    var dLen by mutableStateOf(true)
    var dChain by mutableStateOf(false)
    var dArea by mutableStateOf(false)
    var listOpen by mutableStateOf(false)
    var coachStop by mutableStateOf(false)
    var coachPlay by mutableIntStateOf(0)
    var kp by mutableStateOf<Kp?>(null)
    var laserOn by mutableStateOf(false)
    val zooms = mapOf("plan" to Zoom(), "front" to Zoom(), "3d" to Zoom())
    /** The last style and sizes used per kind: first in the style window, with "Yana shu". */
    val last = mutableStateMapOf<String, Pair<String, Map<String, Int>>>()
    private val past = mutableStateListOf<Pair<Room, String>>()
    private val future = mutableStateListOf<Pair<Room, String>>()
    val canUndo get() = past.isNotEmpty()
    val canRedo get() = future.isNotEmpty()

    fun save(r: Room) = write(r)

    /** The piece being dragged and what it snapped to (the walls glowing green), while a finger holds it. */
    var iwMag by mutableStateOf<uz.metrx.app.geo.IwSnap?>(null)
    /** The "Devor qo‘shish" window is open. */
    var iwWin by mutableStateOf(false)
    /** The piece just added (shown as a ghost until it is moved or another is picked). */
    var ghostId by mutableStateOf<String?>(null)

    /** A change: [f] makes the new room (null or the same room: nothing happened); a toast with "Ortga qaytarish". */
    fun commit(app: App, msg: String, warn: Boolean = false, f: (Room) -> Room?): Boolean {
        val r0 = room ?: return false
        // items on inner faces keep their face by key (letters move when a piece goes or the shape changes)
        val r1 = f(r0)?.let { uz.metrx.app.geo.syncFaces(it, app.settings.angleSnap) } ?: return false
        if (r1 == r0) return false
        past.add(r0 to msg); if (past.size > 40) past.removeAt(0)
        future.clear()
        live = null
        write(r1)
        fixSel()
        app.haptic(if (warn) Hap.WARN else Hap.CONFIRM)
        app.toast = ToastMsg(msg, if (warn) ToastKind.INFO else ToastKind.OK, app.t("ux.undo"), onAction = { undo(app) })
        return true
    }

    /** A slide or an edge drag that started from [snap] ends: one undo step for the whole drag. */
    fun endLive(app: App, snap: Room, msg: String) {
        val r1 = live?.let { uz.metrx.app.geo.syncFaces(it, app.settings.angleSnap) } ?: return
        live = null
        if (r1 == snap) { write(snap); return }
        past.add(snap to msg); future.clear()
        write(r1)
        app.haptic(Hap.CONFIRM)
        app.toast = ToastMsg(msg, ToastKind.OK, app.t("ux.undo"), onAction = { undo(app) })
    }

    fun undo(app: App) {
        val e = past.removeLastOrNull() ?: return
        room?.let { future.add(it to e.second) }
        write(e.first); fixSel(); app.haptic(Hap.TICK)
        app.toast = ToastMsg(app.t("re.undone", "m" to e.second), ToastKind.OK, app.t("re.redo"), onAction = { redo(app) })
    }

    fun redo(app: App) {
        val e = future.removeLastOrNull() ?: return
        room?.let { past.add(it to e.second) }
        write(e.first); fixSel(); app.haptic(Hap.TICK)
        app.toast = ToastMsg(app.t("re.redone", "m" to e.second), ToastKind.OK)
    }

    /** A selection whose item or wall is gone is dropped. */
    fun fixSel() {
        val r = room ?: return
        when (val s = sel) {
            is ReSel.Item -> if (r.openings.none { it.id == s.id } && r.points.none { it.id == s.id }) sel = null
            is ReSel.Wall -> if (uz.metrx.app.geo.allWalls(r).none { it.id == s.id }) sel = null
            is ReSel.Piece -> if (r.inner.none { it.id == s.id }) sel = null
            null -> {}
        }
        if (uz.metrx.app.geo.allWalls(r).none { it.id == fw }) fw = walls(r).firstOrNull()?.id ?: "A"
        if (ghostId != null && r.inner.none { it.id == ghostId }) ghostId = null
    }

    fun op(id: String?) = room?.openings?.firstOrNull { it.id == id }
    fun pt(id: String?) = room?.points?.firstOrNull { it.id == id }
    val selOp: Opening? get() = (sel as? ReSel.Item)?.let { op(it.id) }
    val selPt: SitePoint? get() = (sel as? ReSel.Item)?.let { pt(it.id) }
    val selWall: String? get() = (sel as? ReSel.Wall)?.id
    /** The selected inner wall: the piece itself, or the piece of the selected inner face. */
    val selPiece: uz.metrx.app.data.InnerWall? get() {
        val r = room ?: return null
        return when (val s = sel) {
            is ReSel.Piece -> r.inner.firstOrNull { it.id == s.id }
            is ReSel.Wall -> uz.metrx.app.geo.innerFaces(r).firstOrNull { it.id == s.id }?.let { f -> r.inner.firstOrNull { it.id == f.pid } }
            else -> null
        }
    }
    /** Only the piece is selected (not one of its faces). */
    val selPieceOnly: uz.metrx.app.data.InnerWall? get() = (sel as? ReSel.Piece)?.let { s -> room?.inner?.firstOrNull { it.id == s.id } }
}

/** The sessions in progress by key (a room flow's draft key, or "ed:<pid>:<rid>" for the editor). */
object ReSessions {
    private val map = HashMap<String, ReSession>()
    fun get(k: String) = map[k]
    fun put(s: ReSession) { map[s.key] = s }
    fun drop(k: String) { map.remove(k) }
}

/* ---------------- reading the room ---------------- */

fun App.reSnap() = settings.angleSnap

/** Wall [id]'s length, mm (an outer wall or an inner face). */
fun App.wallL(r: Room, id: String): Int = reAll(r, reSnap()).firstOrNull { it.id == id }?.L ?: 0

/** The walls' lengths by id (the inner faces too). */
fun App.wallLens(r: Room): Map<String, Int> = reAll(r, reSnap()).associate { it.id to it.L }

fun roomH(r: Room) = r.dim("H").v ?: 2700

/** A wall's height: an inner face its piece's (a half wall 1 100), an outer wall the room's. */
fun App.wallH(r: Room, id: String): Int = uz.metrx.app.geo.wallHOf(r, id, reSnap())

/** Whether wall [id] is an inner face. */
fun App.isInner(r: Room, id: String): Boolean = uz.metrx.app.geo.isInnerWall(r, id, reSnap())

/** The room's problems (Tekshiruv): the items' rules, then the inner walls in a door's way. */
fun App.issuesOf(r: Room): List<ReIssue> = roomIssues(wallLens(r), roomH(r), r.openings, r.points,
    uz.metrx.app.geo.innerFaces(r, reSnap()).associate { it.id to it.h }) + uz.metrx.app.geo.iwIssues(r, reSnap())

/** An issue in words. */
fun App.issueText(q: ReIssue): String {
    val a = q.args.mapValues { (k, v) -> when {
        v is Int -> mm(v)
        k == "k" && (q.key == "iw.i.swing" || q.key == "iw.i.block") -> t("iw.k.$v")
        k == "k" || k == "o" || k == "a" -> kindName(v.toString())
        k == "b" -> kindLow(v.toString())
        else -> v
    } }
    // "Rozetka deraza ustida": the second kind lower-case in the middle of the sentence
    val b = if (q.key == "re.i.onOp") a + ("o" to kindLow(q.args["o"].toString()))
        // the piece's name, as the iPhone hands it ({n})
        else if (q.key == "iw.i.swing" || q.key == "iw.i.block") a + ("n" to t("iw.k.${q.args["k"]}"))
        else a
    return t(q.key, *b.map { it.key to it.value }.toTypedArray())
}

/** The neighbour walls of [id] (the corner each distance goes to); an inner face ends in the room ("uchi"). */
fun App.neighbours(r: Room, id: String): Pair<String, String> {
    if (isInner(r, id)) return t("iw.end") to t("iw.end")
    val ws = reWalls(r, reSnap()); val i = ws.indexOfFirst { it.id == id }; val n = ws.size
    if (i < 0 || n == 0) return "?" to "?"
    return ws[(i - 1 + n) % n].id to ws[(i + 1) % n].id
}

/** An item's size line: "800 × 2 100", "1 500 × 1 500 · tokcha 900", "eshik 700 × 2 100 + deraza 1 200 × 1 400", "h 300". */
fun App.sizeLine(o: Opening): String {
    val st = styleId(o)
    if (st == "balcony") return t("re.szBal", "dw" to mm(o.dw), "h" to mm(o.h), "ww" to mm(o.w - o.dw), "wh" to mm(o.wh))
    return mm(o.w) + " × " + mm(o.h) + if (o.type == "window") (if (st == "pano") " · " + t("re.fromFloor") else " · " + t("re.sillV", "v" to mm(o.sill))) else ""
}

fun App.sizeLine(p: SitePoint): String = (if (p.t == "rad" || p.t == "ac") t("re.widthV", "v" to mm(valsOf(p)["pw"] ?: 0)) + " · " else "") + "h " + mm(p.h)

/** The style window's "Yana shu · 800 × 2 100" and the cards' size lines. */
fun App.valsLine(kind: String, style: String, v: Map<String, Int>): String = when {
    isOpenKind(kind) && style == "balcony" -> t("re.balLine", "d" to mm(v["dw"] ?: 0), "w" to mm(v["ww"] ?: 0))
    isOpenKind(kind) -> mm(v["w"] ?: 0) + " × " + mm(v["h"] ?: 0)
    else -> (v["pw"]?.let { t("re.widthV", "v" to mm(it)) + " · " } ?: "") + "h " + mm(v["ph"] ?: 0)
}

/* ---------------- making and placing items ---------------- */

/** A new [kind] on wall [wall] centred [center] mm from its start, sized to fit the wall and the room's height. */
fun App.mkItem(r: Room, kind: String, wall: String, center: Double): Any {
    val L = wallL(r, wall); val rh = wallH(r, wall)
    if (isOpenKind(kind)) {
        var w = if (kind == "door") 800 else 1500; var h = if (kind == "door") 2100 else 1500; val sill = if (kind == "door") 0 else 900
        w = minOf(w, L / 10 * 10)
        if (kind == "window" && sill + h > rh) h = max(300, rh - sill - 100)
        if (kind == "door" && h > rh) h = rh - 100
        val off = (Math.round((center - w / 2.0) / 10) * 10).toInt().coerceIn(0, max(0, L - w))
        return Opening(uid(), kind, wall, w, h, off, sill, style = if (kind == "door") "single" else "double", sw = if (kind == "door") "inL" else "L")
    }
    val st = styleOf(kind, null)
    val (_, d, mh) = pointDefaults(kind)
    return SitePoint(uid(), kind, wall, Math.round(center).toInt().coerceIn(0, L), POINT_HS[kind]?.first() ?: 500, d, mh, "manual", st.id, st.std["pw"] ?: 0)
}

/** The item as it stands in the pick: the ghost on the wall, sized by the steps typed so far. */
fun App.pkBuild(s: ReSession, pk: Pick): Any {
    val r = s.room ?: return pk.base
    val st = pk.style ?: return pk.base
    return when (val b = pk.base) {
        is Opening -> applyVals(b, st, pk.v, wallL(r, pk.wall), pk.center)
        is SitePoint -> applyVals(b, st, pk.v)
        else -> b
    }
}

/** Puts a new [kind] on [wall] near [center] (a tap on the wall, a wall chip, a wall tool): the style window opens. */
fun App.placeAt(s: ReSession, kind: String, wall: String, center: Double, how: String) {
    val r = s.room ?: return
    val L = wallL(r, wall)
    var it = mkItem(r, kind, wall, center)
    if (it is Opening) freeSpot(it, r.openings, L)?.let { d -> it = (it as Opening).copy(off = d) }
    else if (it is SitePoint) it = (it as SitePoint).copy(off = magnet(0, L, (it as SitePoint).off.toDouble(), 1e-3).v)
    beginPlace(s, it, how)
}

/** The ghost is on the wall: the style window opens over the dimmed plan. */
fun App.beginPlace(s: ReSession, it: Any, how: String, fromFront: Boolean = false) {
    s.arm = null; s.ghost = null; s.mag = null
    val (kind, wall, center) = when (it) {
        is Opening -> Triple(it.type, it.wall, it.off + it.w / 2.0)
        is SitePoint -> Triple(it.t, it.wall, it.off.toDouble())
        else -> return
    }
    s.pk = Pick("new", how, kind, wall, center, null, it, "style", null, ph0 = if (fromFront && it is SitePoint) it.h else null)
    haptic(Hap.TICK)
}

/** "Turi" / "O‘lcham" on the selected item: the same window, its place kept. */
fun App.pkOpenFor(s: ReSession, mode: String) {
    val o = s.selOp; val p = s.selPt
    s.pk = when {
        o != null -> Pick(mode, "edit", o.type, o.wall, o.off + o.w / 2.0, o.id, o, if (mode == "retype") "style" else "size", styleId(o), valsOf(o))
        p != null -> Pick(mode, "edit", p.t, p.wall, p.off.toDouble(), p.id, p, if (mode == "retype") "style" else "size", styleId(p), valsOf(p))
        else -> return
    }
    haptic(Hap.TICK)
}

/** A style card picked: the sizes start from the item's own (same style) or the style's standard. */
fun App.pkStyle(s: ReSession, id: String) {
    val pk = s.pk ?: return
    val r = s.room ?: return
    val orig = pk.base
    val same = pk.mode != "new" && ((orig is Opening && styleId(orig) == id) || (orig is SitePoint && styleId(orig) == id))
    var v = if (same) (if (orig is Opening) valsOf(orig) else valsOf(orig as SitePoint)) else stdVals(pk.kind, styleOf(pk.kind, id), wallH(r, pk.wall))
    if (pk.ph0 != null && v["ph"] != null) v = v + ("ph" to pk.ph0)
    s.pk = pk.copy(style = id, v = v, phase = "size", step = 0, note = null, again = false)
    haptic(Hap.TICK)
}

/** "Yana shu": the last style and sizes, at once. */
fun App.pkAgain(s: ReSession) {
    val pk = s.pk ?: return
    val l = s.last[pk.kind] ?: return
    s.pk = pk.copy(style = l.first, v = l.second, again = true)
    pkFinish(s)
}

/** "Qo‘yish" / "Saqlash": a problem sends back to its step; else the item is put on the wall (or changed). */
fun App.pkFinish(s: ReSession) {
    val pk = s.pk ?: return
    val r = s.room ?: return
    val st = pk.style ?: return
    val L = wallL(r, pk.wall)
    checkAll(pk.kind, st, pk.v, L, wallH(r, pk.wall))?.let { (i, _) -> s.pk = pk.copy(phase = "size", step = i, note = null); haptic(Hap.WARN); return }
    s.last[pk.kind] = st to pk.v
    s.pk = null
    val built = pkBuild(s, pk)
    val nm = kindName(pk.kind) + " · " + styleName(pk.kind, st)
    if (pk.mode == "new") {
        var it = built
        if (it is Opening && r.openings.any { o -> overlaps(it as Opening, o) }) freeSpot(it as Opening, r.openings, L)?.let { d -> it = (it as Opening).copy(off = d) }
        val ov = it is Opening && r.openings.any { o -> overlaps(it as Opening, o) }
        val d = when (val x = it) { is Opening -> distsOf(x, L); is SitePoint -> distsOf(x, L); else -> null }
        val msg = t("re.placed", "n" to nm, "w" to pk.wall, "a" to mm(d?.left ?: 0), "b" to mm(d?.right ?: 0)) + if (ov) " · " + t("re.overNote") else ""
        s.commit(this, msg, warn = ov) { rr ->
            when (val x = it) { is Opening -> rr.copy(openings = rr.openings + x); is SitePoint -> rr.copy(points = rr.points + x); else -> null }
        }
        val id = when (val x = it) { is Opening -> x.id; is SitePoint -> x.id; else -> null }
        if (id != null) s.sel = ReSel.Item(id)
        s.fw = pk.wall; s.strip = null; s.coachStop = true; s.coachPlay = 0
        return
    }
    val line = when (val x = built) { is Opening -> sizeLine(x); is SitePoint -> sizeLine(x); else -> "" }
    s.commit(this, "$nm · $line") { rr ->
        when (val x = built) {
            is Opening -> { var y: Opening = x; if (rr.openings.any { o -> overlaps(y, o) }) freeSpot(y, rr.openings, L)?.let { d -> y = y.copy(off = d) }
                rr.copy(openings = rr.openings.map { o -> if (o.id == y.id) y else o }) }
            is SitePoint -> rr.copy(points = rr.points.map { p -> if (p.id == x.id) x else p })
            else -> null
        }
    }
}

/** The size step's field as the steps ask it. */
fun pkField(pk: Pick): String? = pk.style?.let { pkSteps(pk.kind, it).getOrNull(pk.step) }

/* ---------------- editing the selected item ---------------- */

private fun App.warn(text: String) { toast = ToastMsg(text, ToastKind.ERROR); haptic(Hap.WARN) }

fun App.setOp(s: ReSession, msg: String, f: (Opening) -> Opening?) {
    val id = s.selOp?.id ?: return
    s.commit(this, msg) { r -> val o = r.openings.firstOrNull { it.id == id } ?: return@commit null; val n = f(o) ?: return@commit null; r.copy(openings = r.openings.map { if (it.id == id) n else it }) }
}

fun App.setPt(s: ReSession, msg: String, f: (SitePoint) -> SitePoint?) {
    val id = s.selPt?.id ?: return
    s.commit(this, msg) { r -> val p = r.points.firstOrNull { it.id == id } ?: return@commit null; val n = f(p) ?: return@commit null; r.copy(points = r.points.map { if (it.id == id) n else it }) }
}

fun App.setW(s: ReSession, v: Int) {
    val o = s.selOp ?: return; val r = s.room ?: return
    val L = wallL(r, o.wall)
    if (v == o.w) return
    if (v > L) { warn(t("re.noFit", "w" to o.wall, "l" to mm(L), "v" to mm(v))); return }
    if (o.balcony && v < o.dw + 300) { warn(t("re.balMinW", "m" to mm(o.dw + 300))); return }
    setOp(s, t("re.chW", "n" to kindName(o.type), "a" to mm(o.w), "b" to mm(v))) { x ->
        val c = x.off + x.w / 2.0
        x.copy(w = v, off = (Math.round((c - v / 2.0) / 10) * 10).toInt().coerceIn(0, max(0, L - v)))
    }
}

fun App.setH(s: ReSession, v: Int) {
    val o = s.selOp ?: return; val r = s.room ?: return
    if (v == o.h) return
    if (z0Of(o) + v > wallH(r, o.wall)) { warn(t("re.overCeil", "a" to mm(z0Of(o) + v), "b" to mm(wallH(r, o.wall)))); return }
    if (o.balcony && v < o.wh + 100) { warn(t("re.e.balDoor", "m" to mm(o.wh + 100), "u" to t("u.mm"))); return }
    setOp(s, t("re.chH", "n" to kindName(o.type), "a" to mm(o.h), "b" to mm(v))) { it.copy(h = v) }
}

fun App.setSill(s: ReSession, v: Int) {
    val o = s.selOp ?: return; val r = s.room ?: return
    if (v == o.sill) return
    if (v + o.h > wallH(r, o.wall)) { warn(t("re.overCeil", "a" to mm(v + o.h), "b" to mm(wallH(r, o.wall)))); return }
    setOp(s, t("re.chSill", "a" to mm(o.sill), "b" to mm(v))) { it.copy(sill = v) }
}

fun App.setPh(s: ReSession, v: Int) {
    val p = s.selPt ?: return; val r = s.room ?: return
    if (v == p.h) return
    if (v > wallH(r, p.wall)) { warn(t("re.ceilShort")); return }
    setPt(s, t("re.chH", "n" to kindName(p.t), "a" to mm(p.h), "b" to mm(v))) { it.copy(h = v) }
}

/** The distance from the near corner (an opening's edge, a point's centre), mm. */
fun App.setDist(s: ReSession, v: Int, msg: String) {
    val o = s.selOp; val p = s.selPt
    if (o != null) { if (v != o.off) setOp(s, msg) { it.copy(off = v) } }
    else if (p != null) { if (v != p.off) setPt(s, msg) { it.copy(off = v) } }
}

/** Surish: ±10 / ±100 mm, to the start, middle or end. */
fun App.moveSel(s: ReSession, a: String) {
    val r = s.room ?: return
    val o = s.selOp; val p = s.selPt
    val wall = o?.wall ?: p?.wall ?: return
    val L = wallL(r, wall); val w = o?.w ?: 0; val hi = max(0, L - w); val cur = o?.off ?: p!!.off
    val v = when (a) { "s" -> 0; "e" -> hi; "c" -> hi / 2; else -> (cur + a.toInt()).coerceIn(0, hi) }
    if (v == cur) { warn(t("re.noMove")); return }
    setDist(s, v, t("re.moved", "n" to kindName(o?.type ?: p!!.t), "a" to mm(v), "b" to mm(hi - v)))
}

fun App.delSel(s: ReSession) {
    val o = s.selOp; val p = s.selPt
    val nm = kindName(o?.type ?: p?.t ?: return)
    val id = o?.id ?: p!!.id
    s.commit(this, t("re.gone", "n" to nm)) { r -> r.copy(openings = r.openings.filter { it.id != id }, points = r.points.filter { it.id != id }) }
    s.sel = null; s.strip = null
}

/** Nusxa: a copy 150 mm past it (or before it), never over another. */
fun App.dupSel(s: ReSession) {
    val r = s.room ?: return
    val o = s.selOp; val p = s.selPt
    if (o != null) {
        val L = wallL(r, o.wall)
        val ok = listOf(o.off + o.w + 150, o.off - o.w - 150).firstOrNull { d -> d >= 0 && d + o.w <= L && r.openings.none { overlaps(o.copy(id = "copy", off = d), it) } }
        if (ok == null) { warn(t("re.noCopy", "w" to o.wall)); return }
        val c = o.copy(id = uid(), off = ok)
        s.commit(this, t("re.copied", "n" to kindName(o.type), "v" to mm(ok))) { it.copy(openings = it.openings + c) }
        s.sel = ReSel.Item(c.id)
    } else if (p != null) {
        val L = wallL(r, p.wall)
        val d = if (p.off + 250 <= L) p.off + 250 else max(0, p.off - 250)
        val c = p.copy(id = uid(), off = d)
        s.commit(this, t("re.copied", "n" to kindName(p.t), "v" to mm(d))) { it.copy(points = it.points + c) }
        s.sel = ReSel.Item(c.id)
    }
}

/* ---------------- walls and the room ---------------- */

/** Every item kept on its wall after the walls changed. */
fun App.clampItems(r: Room): Room {
    val lens = wallLens(r)
    val kept = ArrayList<Opening>()
    r.openings.filter { it.wall in lens }.forEach { o0 ->
        val L = lens[o0.wall]!!; val w = minOf(o0.w, L / 10 * 10)
        var o = o0.copy(w = w, off = o0.off.coerceIn(0, max(0, L - w)))
        // a shorter wall may push two openings over each other: the later one moves to the nearest free place
        if (kept.any { overlaps(o, it) }) freeSpot(o, kept, L)?.let { d -> o = o.copy(off = d) }
        kept += o
    }
    return r.copy(
        openings = kept,
        points = r.points.filter { it.wall in lens }.map { p -> p.copy(off = p.off.coerceIn(0, lens[p.wall]!!)) })
}

/** Whether wall [id] can be typed: a rectangle's A and B, a drawn room's measured walls (not the worked-out ones). */
fun App.wallEditable(r: Room, id: String): Boolean {
    val w = walls(r, reSnap()).firstOrNull { it.id == id } ?: return false
    if (!r.isPoly) return !w.derived
    return r.dims[id]?.v != null
}

/** Uzunlik: a wall's new length (300 – 999 999 mm; above 30 m the toast says "katta devor — to‘g‘rimi?"). */
fun App.setWallLen(s: ReSession, id: String, v: Int, pre: String = "") {
    val r = s.room ?: return
    if (!wallEditable(r, id)) { warn(t("re.autoWall")); return }
    if (v < WALL_MIN || v > WALL_MAX) { warn(t("re.wallRange")); return }
    val old = wallL(r, id)
    if (v == old) { toast = ToastMsg(pre + t("re.wallSame", "w" to id, "v" to mm(v))); return }
    val key = if (r.isPoly) id else walls(r, reSnap()).first { it.id == id }.dimKey
    val n = r.copy(dims = r.dims + (key to Dim(v, "manual")))
    if (n.isPoly && !polyGeo(n, reSnap()).solved) { warn(t("re.noClose")); return }
    s.commit(this, pre + t("re.wallCh", "w" to id, "a" to mm(old), "b" to mm(v)) + if (bigWall(v)) " · " + t("re.bigShort") else "") { clampItems(n) }
}

fun App.setThick(s: ReSession, id: String, v: Int) {
    val r = s.room ?: return
    val o = thickOf(r, id)
    if (v == o) return
    s.commit(this, t("re.thickCh", "w" to id, "a" to "$o", "b" to "$v")) { it.copy(thick = it.thick + (id to v)) }
}

fun App.setRoomH(s: ReSession, v: Int) {
    val r = s.room ?: return
    val o = roomH(r)
    if (v == o) return
    s.commit(this, t("re.rhCh", "a" to mm(o), "b" to mm(v))) { it.copy(dims = it.dims + ("H" to Dim(v, "manual"))) }
}

fun App.rotateRoom(s: ReSession, d: Int) {
    s.commit(this, t(if (d > 0) "re.rotR" else "re.rotL")) { it.copy(rot = ((it.rot + d) % 4 + 4) % 4) }
}

fun App.mirrorIt(s: ReSession) { s.commit(this, t("re.mirrored")) { mirrorRoom(it, reSnap()) } }

/** Shakl: another shape at its standard sizes; doors, windows and points stay on the walls that are still there. */
fun App.changeShape(s: ReSession, k: String) {
    val r = s.room ?: return
    if (k == "free") { toast = ToastMsg(t("re.freeMsg"), ToastKind.INFO); return }
    val sh = RoomShape.of(k) ?: return
    val cur = r.poly?.template?.removePrefix("rsh.") ?: if (r.isPoly) "" else "rect"
    if (cur == k) return
    val made = shapeToRoom(ShapeSpec(sh), emptyList(), roomH(r), r.id, r.floorId, r.name, r.created, angleSnap = reSnap())?.room ?: return
    // the inner walls stay (those whose middle is still inside the new shape); their items keep their faces
    val P = uz.metrx.app.geo.outline(made, reSnap())
    val inner = r.inner.filter { uz.metrx.app.geo.pip(uz.metrx.app.geo.V2(it.x.toDouble(), it.y.toDouble()), P) }
    val n = clampItems(uz.metrx.app.geo.syncFaces(made.copy(views = r.views, wallColor = r.wallColor, floorColor = r.floorColor, features = emptyList(),
        openings = r.openings, points = r.points, thick = r.thick, inner = inner), reSnap()))
    val lost = r.openings.size + r.points.size - n.openings.size - n.points.size
    s.commit(this, t("re.shapeCh", "a" to t(shapeKey(cur)), "b" to t("rsh.s.$k")) + if (lost > 0) " · " + t("re.lost", "n" to lost) else "") { n }
}

fun shapeKey(k: String) = if (k.isEmpty()) "re.shapeOwn" else "rsh.s.$k"

/** The room's shape card id: rect, a room-shape template, or "" for a room drawn by hand. */
fun shapeIdOf(r: Room): String = if (!r.isPoly) "rect" else r.poly?.template?.takeIf { it.startsWith("rsh.") }?.removePrefix("rsh.") ?: ""

/** The room heights offered (the chips), the room's own among them. */
fun roomHeights(r: Room) = (ROOM_HS + roomH(r)).distinct().sorted()

/** The slide's height snaps of a point (its kind's usual heights). */
fun ptSnaps(kind: String) = POINT_HS[kind] ?: emptyList()

/** The top of an opening (for the front view's handles). */
fun opTop(o: Opening) = topOf(o)
