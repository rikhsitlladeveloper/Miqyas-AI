package uz.metrx.app.ui.rooms

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.uid
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.editor.english
import uz.metrx.app.ui.elec.addElecRoom
import uz.metrx.app.ui.furniture.addFurnRoom
import uz.metrx.app.ui.plumb.addPlumbRoom
import uz.metrx.app.ui.tiles.addTileRoom
import uz.metrx.app.ui.win.addWinRoom
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UndoStack
import uz.metrx.app.ui.ux.UxBar
import uz.metrx.app.ui.ux.UxTop
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * Adding a room, the same way in every trade (room-shape build spec §2, approved mockup design/room-shapes/mockup.html):
 * the trade's own sheet asks the room's type and name, then this flow asks its shape (8 picture cards, Ko‘zgu / Burish),
 * one size per step on a plan drawn to scale (or a free sketch, every wall asked plus an optional diagonal), the height,
 * the doors, windows, water, sewer and gas, and shows a summary; "Xonani ochish" makes the room and opens the editor.
 */

/** A room being added: where it goes ([trade] decides how it is made), and everything asked so far. */
class RshDraft(val key: String, val pid: String, val trade: String, val kind: String, val name: String, val wid: String?, val fid: String?, h0: Int) {
    /** shape, sketch, walls, height, ops, summary */
    var screen by mutableStateOf("shape")
    var shape by mutableStateOf("rect")
    var mir by mutableStateOf(false)
    var rot by mutableIntStateOf(0)
    /** The asked values by their index, mm. */
    val vals = mutableStateMapOf<Int, Int>()
    /** The asked value being typed (for a free sketch, the step after the last wall is the diagonal). */
    var step by mutableIntStateOf(0)
    var input by mutableStateOf("")
    var fresh by mutableStateOf(false)
    var err by mutableStateOf<String?>(null)
    /** A free sketch: each wall's direction and its drawn length. */
    var sk by mutableStateOf<RshSketch?>(null)
    var diag by mutableStateOf<Int?>(null)
    var height by mutableIntStateOf(h0)
    var hIn by mutableStateOf("")
    var hFresh by mutableStateOf(true)
    var hErr by mutableStateOf<String?>(null)
    val ops = mutableStateListOf<ROp>()
    var op by mutableStateOf<OpEdit?>(null)
    /** A step opened from the summary: its button reads "Saqlash" and goes back there. */
    var ret by mutableStateOf(false)
    /** +1 for each laser or voice value (the field's green flash); the voice's words and the value it replaced. */
    var flash by mutableIntStateOf(0)
    var heard by mutableStateOf<Pair<String, String>?>(null)
    /** The openings step's toasts' Undo. */
    val undos = UndoStack()
}

/** A free sketch's walls: unit directions in plan coordinates (y down) and the drawn lengths, mm. */
data class RshSketch(val dirs: List<P2>, val hints: List<Int>)

/** A door, window, water, sewer or gas point on wall [wall] (an edge index), [dist] from its start corner; mm. */
data class ROp(val kind: String, val wall: Int, val dist: Int, val w: Int = 0, val h: Int = 0, val sill: Int = 0)

/** An opening being added: [stage] "wall" (pick it on the plan) or "num" (its sizes, [sub] the one asked). */
data class OpEdit(val kind: String, val stage: String = "wall", val wall: Int = -1, val sub: Int = 0, val vals: Map<String, Int> = emptyMap(),
                  val input: String = "", val fresh: Boolean = false, val err: String? = null)

/** The flows in progress, by key (kept while their pages are open, e.g. while the laser radar is on top). */
object RshDrafts {
    private val map = HashMap<String, RshDraft>()
    fun get(k: String) = map[k]
    fun put(d: RshDraft) { map[d.key] = d }
    fun drop(k: String) { map.remove(k) }
}

/** The kinds of openings and points, their asked fields (key, label, usual value) and pictures. */
val OP_KINDS = listOf("door", "window", "water", "sewer", "gas")
fun opFields(kind: String): List<Triple<String, String, Int>> = when (kind) {
    "door" -> listOf(Triple("dist", "rsh.f.dist", 600), Triple("w", "rsh.f.doorW", 900), Triple("h", "rsh.f.doorH", 2100))
    // a window also asks its sill (room-shape build spec §2.6), 900 put in for the maker
    "window" -> listOf(Triple("dist", "rsh.f.dist", 900), Triple("w", "rsh.f.winW", 1500), Triple("h", "rsh.f.winH", 1500), Triple("sill", "rsh.f.sill", 900))
    "water" -> listOf(Triple("dist", "rsh.f.dist", 400))
    "sewer" -> listOf(Triple("dist", "rsh.f.dist", 700))
    else -> listOf(Triple("dist", "rsh.f.dist", 1200))
}

/** The lengths a wall may be, mm (build spec "Limits"). */
const val WALL_MIN = 300
const val WALL_MAX = 20_000
const val H_MIN = 2000
const val H_MAX = 6000

/* ---------------- starting and finishing ---------------- */

/**
 * Starts the flow for a room the trade's sheet named: [trade] furniture, build (into the builder's workspace [wid]),
 * into (the first room of the existing workspace [wid]), tiler, elec, plumb or win; [kind] the trade's room type.
 * [fid]: a room-less furniture piece that goes into the room once it is made.
 */
fun App.startRoomShape(pid: String, trade: String, kind: String, name: String, wid: String? = null, fid: String? = null, replace: Boolean = false) {
    val d = RshDraft(uid(), pid, trade, kind, name, wid, fid, settings.lastRoomH)
    RshDrafts.put(d)
    val r = Route.RoomShape(pid, d.key)
    if (replace) replaceTop(r) else push(r)
}

/** The unit the flow's sizes are typed in: a furniture maker's own (mm by default), the others' app unit. */
fun App.rshUnit(d: RshDraft): LenUnit = if (d.trade == "furniture" || store.get(d.pid)?.isFurniture == true) settings.furnUnit else settings.unit

/** Makes the room as its trade does, with the flow's shape, sizes, height and openings; returns its id. */
private fun App.makeRoom(d: RshDraft): String? {
    val p = store.get(d.pid) ?: return null
    val now = System.currentTimeMillis()
    val rid: String = when (d.trade) {
        "furniture" -> addFurnRoom(d.pid, d.kind, d.name)
        "tiler" -> addTileRoom(d.pid, d.kind, d.name)
        "elec" -> addElecRoom(d.pid, d.kind, d.name)
        "plumb" -> addPlumbRoom(d.pid, d.kind, d.name)
        "win" -> addWinRoom(d.pid, d.name)
        else -> {
            val w = p.floors.firstOrNull { it.id == d.wid } ?: return null
            val r = Room(uid(), w.id, d.name, created = now)
            store.update(d.pid) { it.copy(rooms = it.rooms + r) }
            r.id
        }
    }
    store.update(d.pid) { pr -> pr.copy(rooms = pr.rooms.map { if (it.id == rid) rshRoom(it, d, settings.angleSnap) else it }) }
    if (d.fid != null) placeAfter = rid to d.fid
    settings.keepRoomH(d.height)
    return rid
}

/** "Xonani ochish": the room is made, the editor opens, and a toast offers Undo (which takes the room back out). */
private fun App.finishRoom(d: RshDraft) {
    if (!once()) return
    val before = store.get(d.pid) ?: return
    val rid = makeRoom(d) ?: return
    RshDrafts.drop(d.key)
    replaceTop(Route.Editor(d.pid, rid))
    act(t("rsh.added", "n" to dn(d.name, settings.lang)), {
        store.update(d.pid) { it.copy(floors = before.floors, rooms = before.rooms, elec = before.elec, plumb = before.plumb, troom = before.troom) }
        if (placeAfter?.first == rid) placeAfter = null
        dropMissing()
    })
}

/* ---------------- the trades' "Xona qo‘shish" sheet (mockup typeSheet) ---------------- */

/** The sheet's line under its title: "Aziza Nazarova · 1-qadam: tur va nom". */
@Composable
fun RshSheetSub(p: uz.metrx.app.data.Project) {
    val lang = app().settings.lang
    val who = dn(p.customer, lang).ifBlank { dn(p.name, lang) }
    Text(if (who.isBlank()) tr("rsh.step1n") else tr("rsh.step1", "c" to who), style = ui(13f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
}

/** "Xona turi", over the trade's room-type chips. */
@Composable
fun RshTypeLabel() = Text(tr("rsh.typeL"), style = ui(13f, 700, G.ink2))

/** "Davom etish", with "Keyingi qadam — xona shakli." under it. */
@Composable
fun androidx.compose.foundation.layout.ColumnScope.RshSheetGo(enabled: Boolean, onGo: () -> Unit) {
    uz.metrx.app.ui.components.GBtn(tr("fr.continue"), onGo, enabled = enabled)
    Text(tr("rsh.nextNote"), style = ui(13f, 400, G.ink2, 1.4f), modifier = Modifier.padding(horizontal = 4.dp))
}

@Composable
private fun app() = LocalApp.current

/* ---------------- the screen ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun RoomShapeScreen(rt: Route.RoomShape) {
    val app = LocalApp.current
    val d = RshDrafts.get(rt.key) ?: run { app.pop(); return }
    BackHandler { rshBack(app, d) }
    when (d.screen) {
        "sketch" -> uz.metrx.app.ui.editor.SketchScreen(Route.Sketch(d.pid, d.wid ?: "", d.name), onShape = { mm -> sketchDone(app, d, mm) }, onClose = { go(app, d, "shape") })
        "walls" -> WallsStep(d)
        "height" -> HeightStep(d)
        "ops" -> OpsStep(d)
        "summary" -> SummaryStep(d)
        else -> ShapeStep(d)
    }
}

/** Moves to another screen of the flow; the height step starts from the height kept, selected. */
private fun go(app: App, d: RshDraft, s: String) {
    d.heard = null; d.err = null
    // a step's toast (e.g. "Eshik qo‘shildi") does not follow onto the next screen (mockup go → hideToast)
    if (s != d.screen) app.toast = null
    if (s == "height") { d.hIn = fieldText(d.height, app.rshUnit(d), app.english()); d.hFresh = true; d.hErr = null }
    if (s == "ops") d.op = null
    d.screen = s
}

/** Opens asked value [i] (n: the free sketch's diagonal), with its value selected when it has one. */
private fun setStep(app: App, d: RshDraft, i: Int) {
    val n = rshAsks(d).size
    d.step = i
    val v = if (i < n) d.vals[i] else d.diag
    d.input = v?.let { fieldText(it, app.rshUnit(d), app.english()) } ?: ""
    d.fresh = d.input.isNotEmpty(); d.err = null; d.heard = null
}

/** A value as the field shows it: digits in mm, "3,4" in m. */
private fun fieldText(mm: Int, unit: LenUnit, en: Boolean) = if (unit == LenUnit.MM) mm.toString() else uz.metrx.app.geo.fmtField(mm, unit, en)

private fun rshBack(app: App, d: RshDraft) {
    d.heard = null
    when (d.screen) {
        "shape" -> { RshDrafts.drop(d.key); app.pop() }
        "sketch" -> go(app, d, "shape")
        "walls" -> when {
            d.ret -> { d.ret = false; go(app, d, "summary") }
            d.step > 0 -> setStep(app, d, d.step - 1)
            else -> go(app, d, if (d.shape == "free") "sketch" else "shape")
        }
        "height" -> if (d.ret) { d.ret = false; go(app, d, "summary") } else { val n = rshAsks(d).size; setStep(app, d, if (d.shape == "free") n else n - 1); go(app, d, "walls") }
        "ops" -> { val op = d.op; if (op != null) opBack(app, d, op) else go(app, d, "height") }
        "summary" -> go(app, d, "ops")
        else -> app.pop()
    }
}

/** The compact progress: Shakl, Devorlar, Balandlik, Eshik…, Xulosa. */
@Composable
private fun RProg(cur: Int) {
    val labels = listOf("rsh.p.shape", "rsh.p.walls", "rsh.p.height", "rsh.p.ops", "rsh.p.sum")
    val lineOn = G.cobalt; val lineOff = G.ink.copy(alpha = .12f)
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        labels.forEachIndexed { i, k ->
            val done = i < cur; val on = i == cur
            // the line from the step before (mockup .ps::before): blue once this step is reached
            Column(Modifier.weight(1f).drawWithContent {
                drawContent()
                if (i > 0) {
                    val y = (3 + 11).dp.toPx(); val gap = 13.dp.toPx(); val w = size.width
                    drawLine(if (done || on) lineOn else lineOff, androidx.compose.ui.geometry.Offset(-2.dp.toPx() - w / 2 + gap, y),
                        androidx.compose.ui.geometry.Offset(w / 2 - gap, y), 2.dp.toPx(), androidx.compose.ui.graphics.StrokeCap.Round)
                }
            }.clip(RoundedCornerShape(10.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else Color.Transparent).padding(vertical = 3.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Box(Modifier.size(22.dp).clip(CircleShape).background(if (done) G.cobalt else G.solid).border(2.dp, if (done || on) G.cobalt else G.ink.copy(alpha = .12f), CircleShape),
                    contentAlignment = Alignment.Center) {
                    if (done) MIcon("check", Color.White, 12.dp, 3f) else Text("${i + 1}", style = ui(11f, 800, if (on) G.cobalt2 else G.ink3))
                }
                Text(tr(k), style = ui(10.5f, 700, if (on) G.cobalt2 else if (done) G.ink2 else G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
            }
        }
    }
}

/** A page of the flow: the header, the scrolling body and the bottom bar; the body gets lower while the keyboard is up. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun Page(title: String, sub: String?, prog: Int?, onBack: () -> Unit, bar: @Composable () -> Unit, body: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().imePadding()) {
        UxTop(title, onBack, eyebrow = sub, below = if (prog != null) ({ RProg(prog) }) else null)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) { body() }
        bar()
    }
}

/** The plan picture's box, with Ko‘zgu / Burish on it for the shapes that turn. */
@Composable
private fun PicBox(height: Dp, d: RshDraft?, content: @Composable () -> Unit) {
    val app = LocalApp.current
    Box(Modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(22.dp)).background(if (uz.metrx.app.ui.theme.Theme.dark) Color(0xFF161C30) else Color(0xFFF7F8FC))
        .border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
        content()
        if (d != null && d.shape != "free") Column(Modifier.align(Alignment.TopEnd).padding(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ToolBtn(MIRROR, tr("rsh.mirror"), Modifier.width(116.dp)) { d.mir = !d.mir; app.haptic(Hap.TICK) }
            ToolBtn(ROTATE, tr("rsh.rotate"), Modifier.width(116.dp)) { d.rot = (d.rot + 1) % 4; app.haptic(Hap.TICK) }
        }
    }
}

private const val MIRROR = "M12 3v18M9 7L3.5 17H9zM15 7l5.5 10H15z"
private const val ROTATE = "M20 12a8 8 0 11-2.3-5.6M20 4v5h-5"
private const val PENCIL = "M4 20l4-1L19 8l-3-3L5 16zM14 7l3 3"
private const val HAND = "M8 13V5.5a1.5 1.5 0 013 0V11m0-1.5V4a1.5 1.5 0 013 0v6m0-4.5a1.5 1.5 0 013 0V12m0-4a1.5 1.5 0 013 0v6.5A7.5 7.5 0 0112.5 22h-.7a6 6 0 01-5-2.7L4.2 15a1.6 1.6 0 012.5-2z"

@Composable
private fun ToolBtn(icon: String, label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(11.dp)).background(G.cobalt.copy(alpha = .11f)).clickable(role = Role.Button, onClick = onClick)
        .padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally)) {
        PathIcon(icon, G.cobalt2, 16.dp, 2.2f)
        Text(label, style = ui(12.5f, 800, G.cobalt2), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/* ---------------- 1. the shape ---------------- */

@Composable
private fun ShapeStep(d: RshDraft) {
    val app = LocalApp.current
    Page(tr("rsh.shapeT"), dn(d.name, app.settings.lang), 0, { rshBack(app, d) }, bar = {
        UxBar(tr(if (d.shape == "free") "rsh.drawGo" else "fr.continue"), if (d.shape == "free") "pen" else null, {
            app.haptic(Hap.TICK)
            if (d.shape == "free") go(app, d, "sketch") else { d.ret = false; setStep(app, d, 0); go(app, d, "walls") }
        }, null, false)
    }) {
        Text(tr("rsh.shapeHint"), style = ui(13.5f, 400, G.ink2, 1.4f))
        SHAPES.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { k -> ShapeCard(d, k, Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun ShapeCard(d: RshDraft, k: String, modifier: Modifier) {
    val app = LocalApp.current
    val sel = d.shape == k
    val shape = RoundedCornerShape(22.dp)
    Column(modifier.clip(shape).background(if (sel) G.glass(.85f) else G.glass(.55f)).border(if (sel) 2.5.dp else 1.dp, if (sel) G.cobalt else G.rim, shape).padding(8.dp)) {
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).semantics { selected = sel }.clickable(role = Role.RadioButton) {
            if (d.shape != k) { d.shape = k; d.vals.clear(); d.mir = false; d.rot = 0; d.diag = null; if (k != "free") d.sk = null; d.ops.clear() }
            app.haptic(Hap.TICK)
        }) {
            Box(Modifier.fillMaxWidth().height(96.dp).clip(RoundedCornerShape(16.dp)).background(if (uz.metrx.app.ui.theme.Theme.dark) Color(0xFF161C30) else Color(0xFFF7F8FC))) {
                ShapeThumb(k, if (sel) d.mir else false, if (sel) d.rot else 0, sel, Modifier.fillMaxSize())
                if (sel) Box(Modifier.align(Alignment.TopEnd).padding(5.dp).size(24.dp).clip(CircleShape).background(G.cobalt), contentAlignment = Alignment.Center) { MIcon("check", Color.White, 14.dp, 3f) }
            }
            Text(tr("rsh.s.$k"), style = ui(14f, 800), maxLines = 2, modifier = Modifier.padding(start = 4.dp, top = 8.dp, end = 4.dp))
        }
        // side by side as in the mockup; one under the other only when the words don't fit (Russian)
        if (sel && k != "free") androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 4.dp)) {
            val tm = androidx.compose.ui.text.rememberTextMeasurer()
            val st = ui(12.5f, 800, G.cobalt2)
            val m1 = tr("rsh.mirror"); val r1 = tr("rsh.rotate")
            val dens = androidx.compose.ui.platform.LocalDensity.current
            // each button: 8 + icon 16 + 5 + words + 8
            val words = tm.measure(m1, st).size.width + tm.measure(r1, st).size.width
            val need = with(dens) { words.toDp() } + 80.dp
            val mir = { d.mir = !d.mir; app.haptic(Hap.TICK) }; val rot = { d.rot = (d.rot + 1) % 4; app.haptic(Hap.TICK) }
            if (need <= maxWidth) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ToolBtn(MIRROR, m1, Modifier.weight(1f), mir); ToolBtn(ROTATE, r1, Modifier.weight(1f), rot)
            } else Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                ToolBtn(MIRROR, m1, Modifier.fillMaxWidth(), mir); ToolBtn(ROTATE, r1, Modifier.fillMaxWidth(), rot)
            }
        }
        else Text(if (k == "free") tr(if (sel) "rsh.byFinger" else "rsh.everyWall") else tr("rsh.nAsked", "n" to askCount(k)), style = ui(12f, 500, G.ink2, 1.25f),
            minLines = 2, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.heightIn(min = 40.dp).padding(start = 4.dp, end = 4.dp, top = 4.dp))
    }
}

/* ---------------- 2. the free sketch ---------------- */

/** The sketch's outline in mm (clockwise from the top-left corner): each wall's direction and length go to the walls steps. */
private fun sketchDone(app: App, d: RshDraft, mm: List<uz.metrx.app.data.Pt>) {
    val fsk = uz.metrx.app.geo.freeSketch(mm)
    val dirs = fsk.dirs.map { P2(it.x, it.y) }; val hints = fsk.hints
    if (dirs.size < 3) { app.say("sk.cross", kind = ToastKind.ERROR); return }
    d.sk = RshSketch(dirs, hints); d.vals.clear(); d.diag = null; d.ops.clear(); d.ret = false
    app.haptic(Hap.CONFIRM)
    setStep(app, d, 0); go(app, d, "walls")
}

/* ---------------- 3. the walls ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun WallsStep(d: RshDraft) {
    val app = LocalApp.current
    val unit = app.rshUnit(d); val en = app.english()
    val asks = rshAsks(d)
    val n = asks.size
    val free = d.shape == "free"
    val isD = free && d.step >= n
    val st = d.step
    val live = parseLen(d.input, unit)?.takeIf { it in WALL_MIN..WALL_MAX }
    val vals = HashMap(d.vals).also { if (!isD && live != null) it[st] = live }
    val g = rshGeo(d, vals, app)
    val letters = g.letters
    val hint = if (isD) (Math.round(rshDiagLen(d) / 10) * 10).toInt() else asks[st].def
    val label = if (isD) tr("rsh.diag") else askLabel(asks[st], letters)
    val help = if (isD) tr("rsh.diagD") else askHelp(d, asks[st], letters)
    val sub = if (isD) tr("rsh.diagSub") else tr(if (d.shape == "bay") "rsh.sizeN" else "rsh.wallN", "i" to st + 1, "n" to n)
    val imeOn = WindowInsets.isImeVisible
    val liveTxt = parseLen(d.input, unit)?.let { lenWords(it, unit, en) }
    val look = PlanLook(fmt = lenFmt(app, d), cur = if (isD) null else st, done = vals.keys, liveTxt = if (isD) null else liveTxt, pad = 26f, rp = if (free) 0f else 100f,
        diagK = if (isD) rshDiagK(d) else null, diagCur = isD, diagTxt = if (isD) (liveTxt ?: "?") else null,
        dimTxt = vals.mapValues { lenWords(it.value, unit, en) }, dimWords = tr("rsh.dimW") to tr("rsh.dimD"))
    fun next() = wallsNext(app, d)
    Page(dn(d.name, app.settings.lang) + " · " + tr("rsh.s.${d.shape}"), sub, null, { rshBack(app, d) }, bar = {
        UxBar(tr(if (isD && d.input.isEmpty()) "rsh.skip" else if (d.ret) "common.save" else "common.next"), null, ::next, null, false, mainEnabled = d.input.isNotEmpty() || isD)
    }) {
        // no step dots: "Devor 2 / 4" in the header says it (mockup scrWalls)
        PicBox(if (imeOn) 160.dp else 236.dp, d) {
            PlanPic(g.model, d.mir, d.rot, look, letters, tr("rsh.auto"), tr("rsh.gap"), Modifier.fillMaxSize())
        }
        SizeField("w$st${d.shape}", label, help, d.input, d.fresh, hint, unit, d.err, d.flash, d.heard,
            onText = { d.input = it; d.fresh = false; d.err = null; d.heard = null },
            onNext = ::next,
            onLaser = { mm -> d.heard = null; d.input = fieldText(mm, unit, en); d.fresh = false; d.err = null; d.flash++; app.haptic(Hap.CONFIRM) },
            onVoice = { mm, words -> d.heard = d.input to words; d.input = fieldText(mm, unit, en); d.fresh = false; d.err = null; d.flash++; app.haptic(Hap.CONFIRM) },
            onUnVoice = { d.heard?.let { d.input = it.first }; d.heard = null; app.haptic(Hap.TICK) })
    }
}

/** An asked value's title: "Devor B", "Erker eni". */
@Composable
private fun askLabel(a: RAsk, letters: List<String>): String = when (a.dim) {
    0 -> tr("rsh.bayW"); 1 -> tr("rsh.bayD")
    else -> tr("rsh.wall", "w" to letters.getOrElse(a.edge ?: 0) { "?" })
}

/** The line under it: where to measure. */
@Composable
private fun askHelp(d: RshDraft, a: RAsk, letters: List<String>): String {
    if (d.shape == "bay") return tr(when (a.dim) { 0 -> "rsh.bayWD"; 1 -> "rsh.bayDD"; else -> when (a.edge) { 6 -> "rsh.bayGD"; 7 -> "rsh.bayHD"; else -> "rsh.bayAD" } })
    if (d.shape == "free") return tr("rsh.wallD") + " " + tr("rsh.wallFree")
    if (d.shape == "cut" && a.edge == 3) return tr("rsh.wallD") + " " + tr("rsh.wallCut", "c" to letters.getOrElse(2) { "C" })
    return tr("rsh.wallD")
}

private fun wallsNext(app: App, d: RshDraft) {
    val unit = app.rshUnit(d); val en = app.english()
    val asks = rshAsks(d); val n = asks.size
    val free = d.shape == "free"
    val isD = free && d.step >= n
    d.heard = null
    fun bad(m: String) { d.err = m; app.haptic(Hap.WARN) }
    val range = app.t("rsh.range", "a" to lenWords(WALL_MIN, unit, en), "b" to lenWords(WALL_MAX, unit, en), "u" to app.t(unitKeyOf(unit)))
    if (isD) {
        if (d.input.isEmpty()) { d.diag = null; finishWalls(app, d); return }
        val v = parseLen(d.input, unit)
        if (v == null || v !in WALL_MIN..WALL_MAX) { bad(app.t("rsh.e.enter", "r" to range)); return }
        rshDiagErr(app, d, v)?.let { bad(it); return }
        d.diag = v
        finishWalls(app, d)
        app.toast = ToastMsg(app.t("rsh.diagOk")); return
    }
    val v = parseLen(d.input, unit)
    if (v == null || v !in WALL_MIN..WALL_MAX) { bad(app.t(if (d.shape == "bay" && d.step >= 3) "rsh.e.size" else "rsh.e.wall", "r" to range)); return }
    val vals = HashMap(d.vals).also { it[d.step] = v }
    rshStepErr(app, d, vals, d.step)?.let { bad(it); return }
    d.vals.clear(); d.vals.putAll(vals)
    app.haptic(Hap.TICK)
    when {
        d.ret -> finishWalls(app, d)
        d.step < n - 1 -> setStep(app, d, d.step + 1)
        free -> setStep(app, d, n)
        else -> finishWalls(app, d)
    }
}

private fun finishWalls(app: App, d: RshDraft) { if (d.ret) { d.ret = false; go(app, d, "summary") } else go(app, d, "height") }

fun unitKeyOf(unit: LenUnit) = when (unit) { LenUnit.CM -> "u.cm"; LenUnit.MM -> "u.mm"; else -> "u.m" }

/* ---------------- 4. the height ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun HeightStep(d: RshDraft) {
    val app = LocalApp.current
    val unit = app.rshUnit(d); val en = app.english()
    val imeOn = WindowInsets.isImeVisible
    val live = parseLen(d.hIn, unit)?.takeIf { it in H_MIN..H_MAX }
    fun next() {
        val v = parseLen(d.hIn, unit)
        d.heard = null
        if (v == null || v !in H_MIN..H_MAX) {
            d.hErr = app.t("rsh.e.h", "r" to app.t("rsh.range", "a" to lenWords(H_MIN, unit, en), "b" to lenWords(H_MAX, unit, en), "u" to app.t(unitKeyOf(unit))))
            app.haptic(Hap.WARN); return
        }
        d.height = v; app.haptic(Hap.TICK)
        if (d.ret) { d.ret = false; go(app, d, "summary") } else go(app, d, "ops")
    }
    Page(dn(d.name, app.settings.lang), tr("rsh.hSub"), null, { rshBack(app, d) }, bar = {
        UxBar(tr(if (d.ret) "common.save" else "common.next"), null, ::next, null, false, mainEnabled = d.hIn.isNotEmpty())
    }) {
        PicBox(if (imeOn) 160.dp else 236.dp, null) {
            HeightPic(live?.let { lenWords(it, unit, en) } ?: "?", tr("rsh.floor"), tr("rsh.ceil"), Modifier.fillMaxSize().padding(4.dp))
        }
        SizeField("h", tr("rsh.hT"), tr("rsh.hD"), d.hIn, d.hFresh, 2700, unit, d.hErr, d.flash, d.heard,
            onText = { d.hIn = it; d.hFresh = false; d.hErr = null; d.heard = null }, onNext = ::next,
            onLaser = { mm -> d.heard = null; d.hIn = fieldText(mm, unit, en); d.hFresh = false; d.hErr = null; d.flash++; app.haptic(Hap.CONFIRM) },
            onVoice = { mm, words -> d.heard = d.hIn to words; d.hIn = fieldText(mm, unit, en); d.hFresh = false; d.hErr = null; d.flash++; app.haptic(Hap.CONFIRM) },
            onUnVoice = { d.heard?.let { d.hIn = it.first }; d.heard = null; app.haptic(Hap.TICK) })
    }
}

/* ---------------- 5. doors, windows, water, sewer, gas ---------------- */

/** Wall [i]'s length as the plan has it, mm. */
private fun wallLen(d: RshDraft, i: Int) = rshGeo(d, d.vals).model.edges.getOrNull(i)?.len ?: 0.0

/** The plan's openings, as drawn. */
private fun planOps(d: RshDraft) = d.ops.map { PlanOp(it.kind, it.wall, it.dist, it.w) }

/** "900 × 2 100 · 600 mm dan" or "400 mm burchakdan". */
@Composable
private fun opDesc(it: ROp, unit: LenUnit, en: Boolean): String {
    val u = unitWordOf(unit)
    return if (it.kind == "door" || it.kind == "window") tr("rsh.opDescD", "w" to lenWords(it.w, unit, en), "h" to lenWords(it.h, unit, en), "d" to lenWords(it.dist, unit, en), "u" to u) +
        (if (it.kind == "window") " · " + tr("rsh.opSill", "s" to lenWords(it.sill, unit, en)) else "")
    else tr("rsh.opDescP", "d" to lenWords(it.dist, unit, en), "u" to u)
}

private fun opSay(app: App, d: RshDraft, text: String, undo: () -> Unit) {
    val e = d.undos.push(text, null, undo)
    app.haptic(Hap.CONFIRM)
    app.toast = ToastMsg(text, ToastKind.OK, app.t("ux.undo"), onAction = { if (d.undos.undo(e)) app.haptic(Hap.TICK) })
}

private fun opBack(app: App, d: RshDraft, op: OpEdit) {
    d.heard = null
    val f = opFields(op.kind)
    d.op = when {
        op.stage == "num" && op.sub > 0 -> { val k = f[op.sub - 1].first; val v = op.vals[k]
            op.copy(sub = op.sub - 1, input = v?.let { fieldText(it, app.rshUnit(d), app.english()) } ?: "", fresh = v != null, err = null) }
        op.stage == "num" -> op.copy(stage = "wall", err = null)
        else -> null
    }
}

@Composable
private fun OpsStep(d: RshDraft) {
    val app = LocalApp.current
    val op = d.op
    when {
        op == null -> OpsList(d)
        op.stage == "wall" -> OpWall(d, op)
        else -> OpNum(d, op)
    }
}

@Composable
private fun OpsList(d: RshDraft) {
    val app = LocalApp.current
    val unit = app.rshUnit(d); val en = app.english()
    val g = rshGeo(d, d.vals)
    Page(tr("rsh.opsT"), tr("rsh.opsSub", "n" to dn(d.name, app.settings.lang)), 3, { rshBack(app, d) }, bar = {
        UxBar(tr(if (d.ops.isNotEmpty()) "rsh.ready" else "rsh.skip"), null, { app.haptic(Hap.TICK); go(app, d, "summary") }, null, false)
    }) {
        PicBox(236.dp, null) { PlanPic(g.model, d.mir, d.rot, PlanLook(fmt = lenFmt(app, d), final = true, ops = planOps(d)), g.letters, tr("rsh.auto"), tr("rsh.gap"), Modifier.fillMaxSize()) }
        OP_KINDS.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { k ->
                    val cnt = d.ops.count { it.kind == k }
                    Box(Modifier.weight(1f).heightIn(min = 90.dp).clip(RoundedCornerShape(18.dp)).background(G.glass(.8f)).border(1.dp, G.rim, RoundedCornerShape(18.dp))
                        .clickable(role = Role.Button) { d.op = OpEdit(k); app.haptic(Hap.TICK) }) {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            OpIcon(k, G.ink, Modifier.size(36.dp))
                            Text(tr("rsh.op.$k"), style = ui(12.5f, 700, G.ink, 1.15f), textAlign = TextAlign.Center, maxLines = 2)
                        }
                        if (cnt > 0) Text("$cnt", style = ui(11f, 800, Color.White), textAlign = TextAlign.Center,
                            modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).clip(CircleShape).background(G.cobalt).padding(horizontal = 6.dp, vertical = 1.dp))
                    }
                }
                if (row.size < 3) Box(Modifier.weight((3 - row.size).toFloat()))
            }
        }
        if (d.ops.isEmpty()) Text(tr("rsh.opsHint"), style = ui(12.5f, 400, G.ink2, 1.4f), modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp))
        else {
            Sect(tr("rsh.added2"))
            d.ops.toList().forEachIndexed { i, it ->
                SumRow(tr("rsh.op.${it.kind}") + " · " + tr("rsh.wall", "w" to g.letters.getOrElse(it.wall) { "?" }), opDesc(it, unit, en), small = true, endMin = 40.dp) {
                    Box(Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) {
                        val gone = d.ops.removeAt(i)
                        opSay(app, d, app.t("rsh.opDel", "n" to app.t("rsh.op.${gone.kind}"))) { d.ops.add(min(i, d.ops.size), gone) }
                    }, contentAlignment = Alignment.Center) { MIcon("x", G.ink3, 17.dp, 2f) }
                }
            }
        }
    }
}

@Composable
private fun OpWall(d: RshDraft, op: OpEdit) {
    val app = LocalApp.current
    val g = rshGeo(d, d.vals)
    val name = tr("rsh.op.${op.kind}")
    Page(tr("rsh.whichWall", "n" to name), tr("rsh.tapWall"), 3, { rshBack(app, d) }, bar = {
        UxBar(tr("common.cancel"), null, { d.op = null; app.haptic(Hap.TICK) }, null, false, mainColor = G.ink3)
    }) {
        PicBox(270.dp, null) {
            PlanPic(g.model, d.mir, d.rot, PlanLook(fmt = lenFmt(app, d), pick = true, ops = planOps(d)), g.letters, tr("rsh.auto"), tr("rsh.gap"), Modifier.fillMaxSize()) { i ->
                d.op = op.copy(stage = "num", wall = i, sub = 0, input = "", fresh = false, err = null); app.haptic(Hap.TICK)
            }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.blueWash).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PathIcon(HAND, G.cobalt2, 22.dp, 2f)
            Text(tr("rsh.tapWallD", "n" to name), style = ui(13.5f, 600, G.ink, 1.35f), modifier = Modifier.weight(1f))
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun OpNum(d: RshDraft, op: OpEdit) {
    val app = LocalApp.current
    val unit = app.rshUnit(d); val en = app.english()
    val imeOn = WindowInsets.isImeVisible
    val g = rshGeo(d, d.vals)
    val fs = opFields(op.kind); val f = fs[op.sub]
    val name = tr("rsh.op.${op.kind}")
    val L = wallLen(d, op.wall)
    val letter = g.letters.getOrElse(op.wall) { "?" }
    val live = if (f.first == "sill") (if (op.input.isBlank()) null else parseLen(op.input, unit) ?: 0) else parseLen(op.input, unit)
    val pd = op.vals["dist"] ?: (if (f.first == "dist") live else null)
    val prev = pd?.let { PlanOp(op.kind, op.wall, it, op.vals["w"] ?: (if (f.first == "w") live ?: 0 else 0)) }
    val help = when (f.first) {
        "dist" -> tr(if (op.kind == "door" || op.kind == "window") "rsh.distOpD" else "rsh.distPtD", "n" to name.lowercase(), "w" to letter, "l" to lenWords(L.toInt(), unit, en) + " " + unitWordOf(unit))
        "w" -> tr("rsh.wD")
        "h" -> tr("rsh.hOpD", "n" to name.lowercase())
        else -> tr("rsh.sillD", "v" to lenWords(900, unit, en) + " " + unitWordOf(unit))
    }
    val hint = rshOpHint(d, op)
    fun next() = opNext(app, d, op)
    Page("$name · " + tr("rsh.wall", "w" to letter), "${op.sub + 1} / ${fs.size} · " + tr(f.second), null, { rshBack(app, d) }, bar = {
        UxBar(tr(if (op.sub < fs.size - 1) "common.next" else "rsh.add"), null, ::next, null, false, mainEnabled = op.input.isNotEmpty())
    }) {
        PicBox(if (imeOn) 160.dp else 236.dp, null) {
            PlanPic(g.model, d.mir, d.rot, PlanLook(fmt = lenFmt(app, d), sel = op.wall, corner = op.wall, ops = planOps(d), preview = prev, pad = 22f), g.letters, tr("rsh.auto"), tr("rsh.gap"), Modifier.fillMaxSize())
        }
        SizeField("op${op.kind}${op.wall}${op.sub}", tr(f.second), help, op.input, op.fresh, hint, unit, op.err, d.flash, d.heard,
            onText = { d.op = op.copy(input = it, fresh = false, err = null); d.heard = null },
            onNext = ::next,
            onLaser = { mm -> d.heard = null; d.op = op.copy(input = fieldText(mm, unit, en), fresh = false, err = null); d.flash++; app.haptic(Hap.CONFIRM) },
            onVoice = { mm, words -> d.heard = op.input to words; d.op = op.copy(input = fieldText(mm, unit, en), fresh = false, err = null); d.flash++; app.haptic(Hap.CONFIRM) },
            onUnVoice = { d.heard?.let { h -> d.op = op.copy(input = h.first) }; d.heard = null; app.haptic(Hap.TICK) })
    }
}

private fun opNext(app: App, d: RshDraft, op: OpEdit) {
    val unit = app.rshUnit(d); val en = app.english()
    val fs = opFields(op.kind); val f = fs[op.sub]
    d.heard = null
    val s = op.input
    // the distance and the sill may be 0 (in the corner, on the floor); the sizes may not
    val v: Int? = if (f.first == "sill" || f.first == "dist") (if (s.isBlank()) null else if (s.all { it == '0' || it == ',' || it == '.' }) 0 else parseLen(s, unit)) else parseLen(s, unit)
    val letter = rshGeo(d, d.vals).letters.getOrElse(op.wall) { "?" }
    val e: String? = rshOpErr(app, d, op, v)
    if (e != null) { d.op = op.copy(err = e); app.haptic(Hap.WARN); return }
    val vals = op.vals + (f.first to v!!)
    if (op.sub < fs.size - 1) {
        val nf = fs[op.sub + 1]
        // the window's sill is put in for the maker (900), selected so one key replaces it
        val pre = if (nf.first == "sill") fieldText(rshOpHint(d, op.copy(sub = op.sub + 1, vals = vals)), unit, en) else ""
        d.op = op.copy(sub = op.sub + 1, vals = vals, input = pre, fresh = pre.isNotEmpty(), err = null)
        app.haptic(Hap.TICK); return
    }
    val it = ROp(op.kind, op.wall, vals["dist"] ?: 0, vals["w"] ?: 0, vals["h"] ?: 0, vals["sill"] ?: 0)
    d.op = null
    d.ops.add(it)
    opSay(app, d, app.t("rsh.opAdded", "n" to app.t("rsh.op.${it.kind}"), "w" to letter)) { d.ops.remove(it) }
}

/* ---------------- 6. the summary ---------------- */

@Composable
private fun Sect(t: String) = Text(t, style = ui(13f, 800, G.ink2), modifier = Modifier.padding(start = 4.dp, top = 8.dp))

@Composable
private fun SumRow(label: String, value: String, small: Boolean = false, auto: Boolean = false, endMin: Dp = 108.dp, end: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp))
        .padding(start = 14.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(label, style = ui(14f, 500, G.ink2, 1.3f), modifier = Modifier.weight(1f))
        Text(value, style = if (small) ui(12.5f, 700, if (auto) G.ink2 else G.ink, 1.3f) else num(15.5f, 700, if (auto) G.ink2 else G.ink), textAlign = TextAlign.End,
            // hugs the button, as the mockup's value next to "O‘zgartirish"; a long one wraps instead of squeezing the label
            modifier = Modifier.widthIn(max = 190.dp))
        Box(Modifier.widthIn(min = endMin), contentAlignment = Alignment.CenterEnd) { end() }
    }
}

@Composable
private fun ChangeBtn(label: String, onClick: () -> Unit) {
    Text(label, style = ui(13f, 700, G.cobalt2), maxLines = 1, modifier = Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClick = onClick)
        .padding(horizontal = 8.dp, vertical = 11.dp))
}

@Composable
private fun AutoTag() {
    // a dashed pill, as the derived walls on the plan (mockup .atag)
    val c = G.ink3.copy(alpha = .7f)
    Text(tr("rsh.auto"), style = ui(11.5f, 800, G.ink3).copy(fontStyle = FontStyle.Normal), maxLines = 1,
        modifier = Modifier.padding(end = 6.dp).drawWithContent {
            drawContent()
            val sw = 1.5.dp.toPx(); val r = size.height / 2
            drawRoundRect(c, androidx.compose.ui.geometry.Offset(sw / 2, sw / 2), androidx.compose.ui.geometry.Size(size.width - sw, size.height - sw),
                androidx.compose.ui.geometry.CornerRadius(r, r), style = androidx.compose.ui.graphics.drawscope.Stroke(sw,
                    pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
        }.padding(horizontal = 9.dp, vertical = 3.dp))
}

@Composable
private fun Chip2(t: String) {
    Text(t, style = ui(12.5f, 700), maxLines = 1, modifier = Modifier.clip(RoundedCornerShape(15.dp)).background(G.glass(.8f)).border(1.dp, G.rim, RoundedCornerShape(15.dp))
        .padding(horizontal = 11.dp, vertical = 6.dp))
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun SummaryStep(d: RshDraft) {
    val app = LocalApp.current
    val unit = app.rshUnit(d); val en = app.english()
    val u = unitWordOf(unit)
    val g = rshGeo(d, d.vals, app)
    val asks = rshAsks(d)
    val ch = tr("fz.change")
    fun edit(i: Int) { d.ret = true; setStep(app, d, i); go(app, d, "walls") }
    Page(dn(d.name, app.settings.lang), tr("rsh.sumSub"), 4, { rshBack(app, d) }, bar = {
        UxBar(tr("rsh.open"), null, { app.finishRoom(d) }, null, false, mainEnabled = g.err == null)
    }) {
        PicBox(230.dp, null) {
            PlanPic(g.model, d.mir, d.rot, PlanLook(fmt = lenFmt(app, d), final = true, ops = planOps(d), diagK = if (d.diag != null) rshDiagK(d) else null, diagTxt = d.diag?.let { lenWords(it, unit, en) }),
                g.letters, tr("rsh.auto"), tr("rsh.gap"), Modifier.fillMaxSize())
        }
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val xs = g.model.pts.map { it.x }; val ys = g.model.pts.map { it.y }
            val bw = ((xs.maxOrNull() ?: 0.0) - (xs.minOrNull() ?: 0.0)).toInt(); val bh = ((ys.maxOrNull() ?: 0.0) - (ys.minOrNull() ?: 0.0)).toInt()
            Chip2(tr("rsh.s.${d.shape}"))
            Chip2(lenWords(bw, unit, en) + " × " + lenWords(bh, unit, en) + " " + u)
            Chip2(m2(g.model.pts, en))
            if (g.fixed > .5) Chip2(tr("rsh.spread", "v" to lenWords(g.fixed.toInt(), unit, en) + " " + u))
        }
        if (g.err != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.err, 18.dp, 2f); Text(g.err, style = ui(13.5f, 600, G.err, 1.35f), modifier = Modifier.weight(1f))
        }
        Sect(tr("rsh.wallsT"))
        // in the editor's letter order (a mirrored shape was asked the other way round)
        g.model.edges.withIndex().sortedBy { g.letters.getOrElse(it.index) { "~" } }.forEach { (i, e) ->
            val wl = tr("rsh.wall", "w" to g.letters.getOrElse(i) { "?" })
            if (e.asked != null) SumRow(wl, lenWords(Math.round(e.len).toInt(), unit, en) + " " + u) { ChangeBtn(ch) { edit(e.asked) } }
            else SumRow(wl + (g.angles[i]?.let { " · " + tr("rsh.cutAng", "a" to it) } ?: ""), lenWords(Math.round(e.len).toInt(), unit, en) + " " + u, auto = true) { AutoTag() }
        }
        asks.forEachIndexed { j, a -> if (a.edge == null) SumRow(askLabel(a, g.letters), lenWords(d.vals[j] ?: a.def, unit, en) + " " + u) { ChangeBtn(ch) { edit(j) } } }
        if (d.shape == "free") SumRow(tr("rsh.diagT"), d.diag?.let { lenWords(it, unit, en) + " " + u } ?: tr("rsh.noDiag")) { ChangeBtn(ch) { edit(asks.size) } }
        Sect(tr("rsh.hTitle"))
        SumRow(tr("rsh.hT"), lenWords(d.height, unit, en) + " " + u) { ChangeBtn(ch) { d.ret = true; go(app, d, "height") } }
        Sect(tr("rsh.opsShort"))
        if (d.ops.isEmpty()) SumRow(tr("rsh.opsShort"), tr("rsh.none"), small = true, auto = true) { ChangeBtn(tr("rsh.add")) { d.ret = false; go(app, d, "ops") } }
        else d.ops.forEach { SumRow(tr("rsh.op.${it.kind}") + " · " + g.letters.getOrElse(it.wall) { "?" }, opDesc(it, unit, en), small = true) { ChangeBtn(ch) { d.ret = false; go(app, d, "ops") } } }
    }
}

/** "8,8 m²". */
private fun m2(pts: List<P2>, en: Boolean): String {
    var a = 0.0
    for (i in pts.indices) { val p = pts[i]; val q = pts[(i + 1) % pts.size]; a += p.x * q.y - q.x * p.y }
    return String.format(java.util.Locale.ROOT, "%.1f", abs(a / 2) / 1e6).replace('.', if (en) '.' else ',') + " m²"
}

/** Lengths on the plan in the flow's unit. */
private fun lenFmt(app: App, d: RshDraft): (Double) -> String { val u = app.rshUnit(d); val en = app.english(); return { lenWords(Math.round(it).toInt(), u, en) } }
