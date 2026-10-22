package uz.metrx.app.ui.editor

import uz.metrx.app.ui.furniture.outOfRooms
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import uz.metrx.app.core.Laser
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Pending
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.openingIssue
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.ToastKind
import kotlin.random.Random

/**
 * What the room editor changes, and its undo history (prototype applyDim, edLaser, edConfirm, saveOpening, pushHist…).
 * History is per room, at most 40 steps, in memory only (as in the prototype); a new change clears redo.
 */
class RoomOps(private val app: App) {
    /** The measurement the step card shows, when the builder picked one (prototype U.edFocus / edFocusRid). */
    var focusKey by mutableStateOf<String?>(null)
    var focusRoom by mutableStateOf<String?>(null)
    /** "Measuring again" for this room:key (prototype U.edRe). */
    var again by mutableStateOf<String?>(null)
    var panelOpen by mutableStateOf(false)
    var tipSeen by mutableStateOf(false)
    /** A drawn room's plan mode: "plan", "shape" (move corners) or "diag" (pick two corners), and which room it is for. */
    var polyMode by mutableStateOf("plan")
    var polyRoom by mutableStateOf<String?>(null)
    var diagFirst by mutableStateOf<Int?>(null)
    private var simCount by mutableIntStateOf(0)

    // the name is not in it: a rename has no history, so Undo must not take it back
    private data class Snap(val dims: Map<String, Dim>, val openings: List<Opening>, val poly: uz.metrx.app.data.Poly?, val rot: Int,
                            val points: List<uz.metrx.app.data.SitePoint> = emptyList(), val features: List<uz.metrx.app.data.Feature> = emptyList())
    private val undo = HashMap<String, ArrayDeque<Snap>>()
    private val redo = HashMap<String, ArrayDeque<Snap>>()
    var histTick by mutableIntStateOf(0)
        private set

    /** Plan ↔ 3D on the same page (prototype A.mode): the sheet closes and the drawn room's shape / diagonal modes end. */
    fun mode(pid: String, rid: String, m: String) {
        app.sheet = null; polyMode = "plan"; diagFirst = null
        app.setTop(uz.metrx.app.ui.Route.Editor(pid, rid, m))
    }

    private fun snap(r: Room) = Snap(r.dims, r.openings, r.poly, r.rot, r.points, r.features)
    // a laser reading waiting on a value is not history: one that came after the snapshot stays
    private fun Room.restore(s: Snap) = copy(dims = s.dims.mapValues { (k, d) -> d.copy(pending = dims[k]?.pending ?: d.pending) },
        openings = s.openings, poly = s.poly, rot = s.rot, points = s.points, features = s.features)

    fun canUndo(rid: String) = undo[rid]?.isNotEmpty() == true
    fun canRedo(rid: String) = redo[rid]?.isNotEmpty() == true

    fun room(pid: String, rid: String): Room? = app.store.get(pid)?.rooms?.firstOrNull { it.id == rid }

    /** Changes one room; [hist] records the state before the change for Undo. */
    fun change(pid: String, rid: String, hist: Boolean = true, f: (Room) -> Room) {
        val before = room(pid, rid) ?: return
        if (hist) {
            val u = undo.getOrPut(rid) { ArrayDeque() }
            u.addLast(snap(before)); while (u.size > 40) u.removeFirst()
            redo[rid]?.clear(); histTick++
        }
        app.store.update(pid) { p -> p.copy(rooms = p.rooms.map { if (it.id == rid) f(it) else it }) }
    }

    fun undo(pid: String, rid: String) {
        val r = room(pid, rid) ?: return
        val s = undo[rid]?.removeLastOrNull() ?: return
        redo.getOrPut(rid) { ArrayDeque() }.addLast(snap(r)); histTick++
        app.store.update(pid) { p -> p.copy(rooms = p.rooms.map { if (it.id == rid) it.restore(s) else it }) }
        app.sheet = null
        app.say("ed.undone")
    }

    fun redo(pid: String, rid: String) {
        val r = room(pid, rid) ?: return
        val s = redo[rid]?.removeLastOrNull() ?: return
        undo.getOrPut(rid) { ArrayDeque() }.addLast(snap(r)); histTick++
        app.store.update(pid) { p -> p.copy(rooms = p.rooms.map { if (it.id == rid) it.restore(s) else it }) }
        app.sheet = null
    }

    /* ---------------- measuring ---------------- */

    fun dimLabel(k: String) = when { k == "H" -> app.t("ed.Hs"); k == "T" -> app.t("ed.T"); k.startsWith("X") -> app.t("sk.diagName", "d" to k); else -> app.t("op.wall") + " " + k }

    /** Shows this measurement in the step card (prototype openMeasure, editor.js override). */
    fun focus(rid: String, k: String) { focusRoom = rid; focusKey = k; panelOpen = false; app.sheet = null }

    /** A wall tapped in the plan. Rect C and D copy A and B, so they measure their source. */
    fun select(pid: String, rid: String, wall: String) {
        val r = room(pid, rid) ?: return
        val w = walls(r, app.settings.angleSnap).firstOrNull { it.id == wall }
        if (w != null && w.derived && !r.isPoly) { app.say("ed.derived", "w" to wall, "s" to w.dimKey, kind = ToastKind.INFO); focus(rid, w.dimKey); return }
        if (w != null && r.isPoly && w.status == "calc") app.say("sk.computedTap", "w" to wall, "v" to fmtLen(w.len, uz.metrx.app.geo.LenUnit.M, app.english()), kind = ToastKind.INFO)
        focus(rid, if (w != null) w.dimKey else wall)
    }

    /** A simulated laser reading (prototype simTarget + edLaser): every third one is 2 mm off, like a real laser. */
    fun laser(pid: String, rid: String, k: String) {
        val r = room(pid, rid) ?: return
        val target = simTarget(r, k)
        val n = ++simCount
        val mm = if (n % 3 == 0) target + 2 else target
        change(pid, rid, hist = false) { it.copy(dims = it.dims + (k to it.dim(k).copy(pending = Pending(mm, "sim")))) }
        focusRoom = rid; focusKey = k
    }

    /** The tray's laser button: a reading close to one of this room's walls or its height (prototype traySim). */
    fun trayReading(pid: String, rid: String) {
        val r = room(pid, rid) ?: return
        val pool = uz.metrx.app.geo.stepKeys(r, app.settings.angleSnap).map { simTarget(r, it) }
        val n = app.settings.readings.size
        app.settings.addReading(pool[n % pool.size] + ((n % 3) - 1) * 2, "sim")
    }

    /** Puts a reading on a wall or the height, waiting for confirmation (prototype trayAssign). */
    fun assignReading(pid: String, rid: String, id: String, k: String) {
        val x = app.settings.readings.firstOrNull { it.id == id } ?: return
        // the same limit as a typed value (a 3 m reading is not a wall's thickness)
        val max = uz.metrx.app.geo.dimMax(k)
        if (x.mm > max) {
            app.say("err.max", "max" to fmtLen(max, app.settings.unit, app.english()).replace(Regex("[.,]0+$"), "") + " " + app.unitName(), kind = ToastKind.ERROR); return
        }
        change(pid, rid, hist = false) { it.copy(dims = it.dims + (k to it.dim(k).copy(pending = Pending(x.mm, x.src, "quick")))) }
        app.settings.markReadingUsed(id, dimLabel(k))
        focus(rid, k)
    }

    private fun simTarget(r: Room, k: String): Int = when {
        k == "H" -> Random.nextInt(2500, 3201)
        k == "T" -> 200
        r.isPoly && k.startsWith("X") -> {
            val g = uz.metrx.app.geo.polyGeo(r, app.settings.angleSnap)
            val d = r.poly!!.diags.firstOrNull { it.id == k }
            if (d == null) 3000 else maxOf(10, (Math.hypot(g.verts[d.a].x - g.verts[d.b].x, g.verts[d.a].y - g.verts[d.b].y) / 10).toInt() * 10)
        }
        r.isPoly -> {
            val w = walls(r, app.settings.angleSnap).firstOrNull { it.id == k }
            if (w == null) 3000 else maxOf(10, (Math.hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y) / 10).toInt() * 10)
        }
        else -> Random.nextInt(2400, 6401)
    }

    /** Confirms a value (prototype applyDim): history, the value, the toast with Undo; the card moves on by itself. */
    fun apply(pid: String, rid: String, k: String, mm: Int, src: String) {
        change(pid, rid) { it.copy(dims = it.dims + (k to Dim(mm, src, null))) }
        if (focusKey == k) focusKey = null
        if (again == "$rid:$k") again = null
        app.sheet = null
        app.say("ms.confirmed", "d" to dimLabel(k), "v" to fmtLen(mm, app.settings.unit, app.english(), full = true) + " " + app.unitName(), action = "common.undo") { undo(pid, rid) }
    }

    fun confirm(pid: String, rid: String, k: String) { val p = room(pid, rid)?.dim(k)?.pending ?: return; apply(pid, rid, k, p.mm, p.src) }

    /** Throws the reading away; with a confirmed value the card says "measuring again". */
    fun againReading(pid: String, rid: String, k: String) {
        val r = room(pid, rid) ?: return
        change(pid, rid, hist = false) { it.copy(dims = it.dims + (k to it.dim(k).copy(pending = null))) }
        again = if (r.dim(k).v != null) "$rid:$k" else null
        focusRoom = rid; focusKey = k
    }

    fun remeasure(pid: String, rid: String, k: String) {
        change(pid, rid, hist = false) { it.copy(dims = it.dims + (k to it.dim(k).copy(pending = null))) }
        focusRoom = rid; focusKey = k; again = "$rid:$k"
    }

    fun cancelAgain() { again = null }

    /* ---------------- doors and windows ---------------- */

    fun opName(o: Opening) = app.t(if (o.type == "door") "op.door" else "op.window")

    fun issue(r: Room, o: Opening) = openingIssue(r, o, opName(o), app.settings.unit, app.english(), app.settings.angleSnap)

    fun saveOpening(pid: String, rid: String, o: Opening, isNew: Boolean) {
        // saving from the sheet confirms a dragged (approximate) position
        val clean = o.copy(offDrag = false, sillDrag = false, sill = if (o.type == "door") 0 else o.sill)
        change(pid, rid) { r -> r.copy(openings = if (isNew) r.openings + clean else r.openings.map { if (it.id == o.id) clean else it }) }
        app.sheet = null
        app.say(if (isNew) "op.added" else "op.saved", "o" to opName(o), action = "common.undo") { undo(pid, rid) }
    }

    fun deleteOpening(pid: String, rid: String, o: Opening) {
        change(pid, rid) { r -> r.copy(openings = r.openings.filter { it.id != o.id }) }
        app.sheet = null
        app.say("op.deleted", "o" to opName(o), action = "common.undo") { undo(pid, rid) }
    }

    /** The end of a drag: a position that doesn't fit goes back; a good one is kept and marked approximate. */
    fun moveOpening(pid: String, rid: String, o: Opening, off: Int, sill: Int) {
        val r = room(pid, rid) ?: return
        if (off == o.off && sill == o.sill) return
        val moved = o.copy(off = off, sill = sill)
        if (issue(r, moved) != null) { app.say("op.dragBack", "o" to opName(o), kind = ToastKind.ERROR); return }
        change(pid, rid) { rr -> rr.copy(openings = rr.openings.map {
            if (it.id == o.id) moved.copy(offDrag = it.offDrag || off != o.off, sillDrag = it.sillDrag || sill != o.sill) else it }) }
        app.say("op.moved", "o" to opName(o), action = "common.undo") { undo(pid, rid) }
    }

    /* ---------------- site points (furniture orders) ---------------- */

    fun pointName(t: String) = app.t("pt.$t")

    fun savePoint(pid: String, rid: String, x: uz.metrx.app.data.SitePoint, isNew: Boolean) {
        change(pid, rid) { r -> r.copy(points = if (isNew) r.points + x else r.points.map { if (it.id == x.id) x else it }) }
        app.sheet = null
        app.say(if (isNew) "pt.added" else "pt.saved", "o" to pointName(x.t), action = "common.undo") { undo(pid, rid) }
    }

    fun deletePoint(pid: String, rid: String, x: uz.metrx.app.data.SitePoint) {
        change(pid, rid) { r -> r.copy(points = r.points.filter { it.id != x.id }) }
        app.sheet = null
        app.say("pt.deleted", "o" to pointName(x.t), action = "common.undo") { undo(pid, rid) }
    }

    /* ---------------- columns and niches ---------------- */

    fun saveFeature(pid: String, rid: String, f: uz.metrx.app.data.Feature, isNew: Boolean) {
        change(pid, rid) { r -> r.copy(features = if (isNew) r.features + f else r.features.map { if (it.id == f.id) f else it }) }
        app.sheet = null
        app.say("ft.saved", action = "common.undo") { undo(pid, rid) }
    }

    fun deleteFeature(pid: String, rid: String, f: uz.metrx.app.data.Feature) {
        change(pid, rid) { r -> r.copy(features = r.features.filter { it.id != f.id }) }
        app.sheet = null
        app.say("op.deleted", "o" to app.t("ft.${f.type}"), action = "common.undo") { undo(pid, rid) }
    }

    /* ---------------- the room ---------------- */

    fun rotate(pid: String, rid: String) {
        change(pid, rid) { it.copy(rot = (it.rot + 1) % 4) }
        app.sheet = null
        app.say("ri.rotated", kind = ToastKind.INFO, action = "common.undo") { undo(pid, rid) }
    }

    fun rename(pid: String, rid: String, name: String) { change(pid, rid, hist = false) { it.copy(name = name.trim()) }; app.sheet = null }

    /** Deletes the room at once and offers Undo (prototype deleteRoomEd); leaves the editor for the workspace. */
    fun deleteRoom(pid: String, rid: String) {
        val p = app.store.get(pid) ?: return
        val r = p.rooms.firstOrNull { it.id == rid } ?: return
        val idx = p.rooms.indexOf(r)
        val pieces = p.furniture.filter { it.roomId == rid }
        val inReport = p.reportRooms[rid]   // left out of the report: Undo keeps it out
        app.store.update(pid) { it.copy(rooms = it.rooms.filter { x -> x.id != rid }, reportRooms = it.reportRooms - rid, furniture = with(app) { outOfRooms(it, setOf(rid)) }) }
        app.sheet = null
        app.popTo { it !is Route.Editor && it !is Route.WallView }
        app.dropMissing()   // the room's pages in the other tabs' stacks go too
        app.say("room.deleted", "n" to uz.metrx.app.data.dn(r.name, app.settings.lang), action = "common.undo") {
            app.store.update(pid) { pr -> pr.copy(rooms = pr.rooms.toMutableList().apply { add(idx.coerceIn(0, size), r) },
                reportRooms = if (inReport != null) pr.reportRooms + (rid to inReport) else pr.reportRooms, furniture = pr.furniture.map { f -> pieces.firstOrNull { it.id == f.id } ?: f }) }
        }
    }

    /** The card the editor shows (prototype ed2Focus): the picked measurement, a reading waiting, the next unmeasured one, a problem, or done. */
    data class Focus(val kind: String, val k: String? = null, val issue: Opening? = null, val ft: uz.metrx.app.data.Feature? = null)

    /** Every measurement of the room: its walls and height, then a drawn room's diagonals. */
    fun measureKeys(r: Room): List<String> = stepKeys(r, app.settings.angleSnap) + (r.poly?.diags?.map { it.id } ?: emptyList())

    fun focusOf(r: Room): Focus {
        val keys = measureKeys(r)
        val fk = focusKey
        if (fk != null && focusRoom == r.id && r.dims.containsKey(fk)) {
            val st = r.dim(fk).status
            return Focus(if (st == "conf" && again == "${r.id}:$fk") "again" else st, fk)
        }
        keys.firstOrNull { r.dim(it).status == "recv" }?.let { return Focus("recv", it) }
        keys.firstOrNull { r.dim(it).status == "unset" }?.let { return Focus("unset", it) }
        r.openings.firstOrNull { issue(r, it) != null }?.let { return Focus("bad", issue = it) }
        // a column or niche that no longer fits (the wall or the height changed after it was added)
        r.features.firstOrNull { uz.metrx.app.geo.featureIssue(r, it, app.settings.angleSnap) != null }?.let { return Focus("badFt", ft = it) }
        return Focus("ok")
    }

    /** The next thing to do in a room (prototype hmNext): a reading to confirm, a value to measure, a problem, or done. */
    data class Next(val cls: String, val icon: String, val text: String)

    fun next(r: Room): Next {
        val keys = stepKeys(r, app.settings.angleSnap)
        keys.firstOrNull { r.dim(it).status == "recv" }?.let { return Next("recv", "clock", app.t("hm.next.recv", "w" to dimLabel(it))) }
        keys.firstOrNull { r.dim(it).status == "unset" }?.let { return Next("unset", "dim", app.t("hm.next.unset", "w" to dimLabel(it))) }
        if (r.openings.any { issue(r, it) != null }) return Next("bad", "alert", app.t("hm.next.bad"))
        val a = uz.metrx.app.geo.areas(r, app.settings.angleSnap)
        return Next("ok", "check", when {
            a?.net != null -> app.t("ws.netWall", "v" to uz.metrx.app.geo.fmtArea(a.net, app.english()))
            a != null -> uz.metrx.app.geo.fmtArea(a.floor, app.english()) + " " + app.t("u.m2")
            else -> app.t("hm.next.ok")
        })
    }

    val laserOn get() = app.settings.laser == Laser.CONNECTED

    fun project(pid: String): Project? = app.store.get(pid)
}

fun App.english() = settings.lang == uz.metrx.app.core.Lang.EN
fun App.unitName() = t(if (settings.unit == uz.metrx.app.geo.LenUnit.CM) "u.cm" else "u.m")
