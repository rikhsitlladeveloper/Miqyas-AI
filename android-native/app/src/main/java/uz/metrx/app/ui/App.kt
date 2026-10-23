package uz.metrx.app.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.staticCompositionLocalOf
import uz.metrx.app.core.Settings
import uz.metrx.app.core.Strings
import uz.metrx.app.data.Store
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.main.Tab

/** A page on a tab's stack (prototype: S.nav.stacks[tab] = [{s:'projects'}, {s:'project', id, tab}, …]). */
sealed interface Route {
    data object Root : Route
    data class NewProject(val editId: String? = null) : Route
    /** [view]: the Workspaces tab as a list, the rooms' plans side by side ("2d") or in 3D ("3d", on workspace [floor]). */
    data class Project(val id: String, val tab: String = "rooms", val view: String = "list", val floor: String? = null) : Route
    data class Space(val pid: String, val wid: String) : Route
    data class Note(val pid: String, val wid: String, val iid: String) : Route
    /** [mode]: "plan" or "3d" (prototype top().mode). */
    data class Editor(val pid: String, val rid: String, val mode: String = "plan") : Route
    data class WallView(val pid: String, val rid: String, val wall: String) : Route
    /** Drawing a new room's outline (prototype PAGES.sketch). */
    data class Sketch(val pid: String, val wid: String, val name: String) : Route
    /** Profile → Boshqa sozlamalar (prototype PAGES.settingsMore). */
    data object SettingsMore : Route
    /** Profile → METRX Pro (prototype PAGES.sub). */
    data object Subscription : Route
    /** Profile → Ustaxona sozlamalari, Materiallar va furnitura (furniture makers). */
    data object Workshop : Route
    data object Materials : Route
    /** A furniture order's kitchen designer: [wall] the run shown (null: the first). */
    data class Kitchen(val pid: String, val fid: String, val wall: String? = null, val d3: Boolean = false) : Route
    /**
     * A furniture order's wardrobe designer: [step] 1–5 (place, sizes, doors, inside, material), [sec] the selected section.
     * A bed, a table, a bar counter or a mirror panel opens its own short designer here, unless [mod] (a loft bed's
     * desk or cabinet under it) is to be designed.
     */
    data class Wardrobe(val pid: String, val fid: String, val step: Int = 1, val sec: Int = 0, val d3: Boolean = false, val mod: String? = null) : Route
    /**
     * Adding furniture (gallery v5, 21 Oct 2026): the models by room ([rid] a room it is for, [fromNew] right after a new
     * order); a model's sizes step by step ([fid]: changing a piece's); which room; into a room. [FPlace] places piece
     * [fid], or a new piece of [model] with the sizes [vals] ("s0=3000,h=2700"; null: sizes from the room).
     */
    data class FGallery(val pid: String, val rid: String? = null, val fromNew: Boolean = false) : Route
    /** [vals]: the sizes typed so far ("s0=3400,h=2700"), kept while "Which room?" is on top; the steps open on the summary. */
    data class FSteps(val pid: String, val model: String, val fid: String? = null, val vals: String? = null) : Route
    data class FWhere(val pid: String, val model: String, val vals: String) : Route
    data class FPlace(val pid: String, val fid: String?, val rid: String, val model: String? = null, val vals: String? = null) : Route
    /**
     * A tiler's order: the gallery of layouts ([rid] the room it is for, [fromNew] right after a new order); a layout's
     * steps (a new one from gallery card [model], or layout [lid]); a room's tiles in 3D ([rid]), or a layout without
     * a room ([rid] null, layout [lid]).
     */
    data class TGallery(val pid: String, val rid: String? = null, val fromNew: Boolean = false) : Route
    data class TSteps(val pid: String, val model: String, val lid: String? = null, val rid: String? = null) : Route
    data class TView(val pid: String, val rid: String?, val lid: String? = null) : Route
    /**
     * An electrician's order: the gallery of room kits ([rid] the room it is for, [fromNew] right after a new order); a
     * kit's steps; a room's devices and routes in 3D, from above and wall by wall ([rid] a room, or "free:<id>" one typed by size).
     */
    data class EGallery(val pid: String, val rid: String? = null, val fromNew: Boolean = false) : Route
    data class ESteps(val pid: String, val kit: String, val rid: String? = null) : Route
    data class EView(val pid: String, val rid: String) : Route
    /**
     * A plumber's order: the gallery of room kits ([rid] the room it is for, [fromNew] right after a new order); a kit's
     * steps; a room's fixtures and pipes in 3D, from above and wall by wall ([rid] a room, or "free:<id>" one typed by size).
     */
    data class PGallery(val pid: String, val rid: String? = null, val fromNew: Boolean = false) : Route
    data class PSteps(val pid: String, val kit: String, val rid: String? = null) : Route
    data class PView(val pid: String, val rid: String) : Route
    /**
     * A windows-and-doors order: the gallery of products ([rid] the room, [oid] the opening it is for, [fromNew] right
     * after a new order); where a type goes (openings or a typed size); a product's designer ([iid]); a room's products in
     * 3D and from above ([rid] a room, or "free:<id>" a product without a room).
     */
    data class WGallery(val pid: String, val rid: String? = null, val oid: String? = null, val fromNew: Boolean = false) : Route
    data class WPlace(val pid: String, val kind: String, val rid: String? = null, val oid: String? = null) : Route
    data class WDesign(val pid: String, val iid: String) : Route
    data class WView(val pid: String, val rid: String) : Route
    /** A furniture order's parts and sheet layout, and its workshop pack. */
    data class FCut(val pid: String) : Route
    data class FPack(val pid: String) : Route
    /** The draft report (prototype PAGES.report). */
    data class Report(val pid: String) : Route
    /** An issued quote, frozen (prototype PAGES.quote). */
    data class Quote(val pid: String, val no: Int) : Route
    /** The Measure page, from Home's "O‘lchash" or, scrolled to the calculator, "Kalkulyator" (prototype tab 'measure'). */
    data class Measure(val calc: Boolean = false) : Route
    /** A free drawing or a photo (prototype PAGES.draw / PAGES.photo); [pid] null: a picture of the Measure page. */
    data class Markup(val pid: String?, val iid: String) : Route
    /** The Measure page's live camera (prototype PAGES.liveCam). */
    data object LiveCam : Route
}

/** Bottom sheets. One at a time, like the prototype's U.sheet. */
sealed interface Sheet {
    data object Language : Sheet
    data object Device : Sheet
    data object Currency : Sheet
    data class ProjectMenu(val pid: String) : Sheet
    data class ProjectDelete(val pid: String) : Sheet
    data class NewSpace(val pid: String, val editWid: String? = null) : Sheet
    data class SpaceMenu(val pid: String, val wid: String) : Sheet
    data class SpaceDelete(val pid: String, val wid: String) : Sheet
    data class AddItem(val pid: String, val wid: String, val step: String = "root") : Sheet
    data class ItemMenu(val pid: String, val wid: String, val iid: String) : Sheet
    data class ItemRename(val pid: String, val wid: String, val iid: String) : Sheet
    data class ItemMove(val pid: String, val wid: String, val iid: String) : Sheet
    data class NewRoom(val pid: String, val wid: String) : Sheet
    /** Typing a measurement (prototype SHEETS.measure, manual phase). */
    data class Measure(val pid: String, val rid: String, val k: String) : Sheet
    data class AddOpening(val pid: String, val rid: String) : Sheet
    /** A door or window: a new one ([oid] null, with [type] and [wall]) or an existing one. */
    data class OpeningForm(val pid: String, val rid: String, val oid: String?, val type: String = "door", val wall: String? = null) : Sheet
    /** A trade's calculator settings (tiler, electrician, plumber, windows). */
    data class TradeCalc(val pid: String) : Sheet
    /** A column or a niche: [fid] null for a new one. */
    data class FeatureForm(val pid: String, val rid: String, val fid: String?, val type: String = "column") : Sheet
    data class RoomInfo(val pid: String, val rid: String) : Sheet
    data class RoomRename(val pid: String, val rid: String) : Sheet
    data class Tray(val pid: String, val rid: String) : Sheet
    /** A room card's menu on the workspace page. */
    data class RoomMenu(val pid: String, val rid: String) : Sheet
    data class RoomMove(val pid: String, val rid: String) : Sheet
    /** Adding a door or window from the wall view: the wall is fixed. */
    data class WallAdd(val pid: String, val rid: String, val wall: String) : Sheet
    /** An estimate row: [kind] "mat" or "lab"; [id] null for a new one, which may start with a suggested [name] and [unit]. */
    data class Row(val pid: String, val kind: String, val id: String? = null, val name: String? = null, val unit: String? = null) : Sheet
    /** Floor, perimeter and net wall area of every room (prototype SHEETS.areas). */
    data class Areas(val pid: String) : Sheet
    /** Report language, rooms, notes, 3D views and the report's note (prototype SHEETS.repSetup). */
    data class ReportSetup(val pid: String) : Sheet
    /** Issuing quote №n, or first the builder's name and phone (prototype SHEETS.issue). */
    data class Issue(val pid: String, val builderOnly: Boolean = false) : Sheet
    /** Profile settings (prototype SHEETS.lang report, pdf, defaults, units, roomLabel, info). */
    data object ReportLang : Sheet
    data object PdfParts : Sheet
    data object Defaults : Sheet
    data object Units : Sheet
    data object RoomLabel : Sheet
    data object About : Sheet
    /** The Measure page: typing a reading, the brick settings, sending a reading to a room, the camera picker. */
    data object QmManual : Sheet
    data object BrickSet : Sheet
    data class SendReading(val id: String) : Sheet
    data object CameraPick : Sheet
    /** The markup editor: a line's length, a text mark ([eid] null: a new one at x, y), a photo's caption. */
    data class MkDim(val eid: String) : Sheet
    data class MkText(val eid: String?, val x: Float, val y: Float) : Sheet
    data object MkCaption : Sheet
    /** A Measure page picture: its menu, deleting it, moving it into a project; the live camera's typed length. */
    data object ShotMenu : Sheet
    data object ShotDel : Sheet
    data object ShotTo : Sheet
    data object LcManual : Sheet
    /** Profile → Soha: builder or furniture maker. */
    data object Industry : Sheet
    /** A furniture order: approving it (agreed price and prepayment), adding a payment. */
    data class FApprove(val pid: String) : Sheet
    data class FPay(val pid: String) : Sheet
    /** A site point on a wall of a furniture order's room: a new one ([id] null) on [wall], or an existing one. */
    data class PointForm(val pid: String, val rid: String, val wall: String, val id: String? = null) : Sheet
    /** The workshop's settings and lists: one value, a material, a hardware item ([id] null: a new one). */
    data class WsField(val key: String) : Sheet
    data class MatForm(val id: String?) : Sheet
    data class HwForm(val id: String?) : Sheet
    /** New furniture in a workspace of a furniture order; a piece of furniture's menu and rename. */
    /** A furniture order: a new room (made with its workspace and opened), the install date. */
    /** A new room of a furniture order: [kind] the furniture it is for; [fid] a room-less piece that goes in once it is measured. */
    data class FNewRoom(val pid: String, val kind: String? = null, val fid: String? = null) : Sheet
    /** Which room a room-less piece goes into. */
    data class FPickRoom(val pid: String, val fid: String) : Sheet
    data class FInstall(val pid: String) : Sheet
    data class FMenu(val pid: String, val fid: String) : Sheet
    data class FRename(val pid: String, val fid: String) : Sheet
    /** The kitchen designer: a unit's settings; the library of units ([group] module, appl or space) for [wall]. */
    data class FModule(val pid: String, val fid: String, val mid: String) : Sheet
    data class KLegs(val pid: String, val fid: String) : Sheet
    data class FLibrary(val pid: String, val fid: String, val wall: String, val group: String) : Sheet
    /** The wardrobe designer: one size ([key] w, h, d, x or secW of section [sec]), an insert, more inserts; materials of any furniture. */
    data class WField(val pid: String, val fid: String, val key: String, val sec: Int = 0) : Sheet
    data class WInsert(val pid: String, val fid: String, val sec: Int, val idx: Int) : Sheet
    data class WMore(val pid: String, val fid: String, val sec: Int) : Sheet
    /** A bed's, a table's, a mirror's… size ([key]) of box [mid] (furniture/Items.kt itemSet). */
    data class IField(val pid: String, val fid: String, val mid: String, val key: String) : Sheet
    data class FMats(val pid: String, val fid: String) : Sheet
    /** A tiler's order: a new room, a shower tray or bath ([fid] null: a new one of [type]), a layout's counting, the prices. */
    data class TNewRoom(val pid: String) : Sheet
    data class TFixForm(val pid: String, val rid: String, val fid: String?, val type: String = "tray") : Sheet
    data class TCount(val pid: String, val lid: String) : Sheet
    data class TPrices(val pid: String?) : Sheet
    /** An electrician's order: a new room, a device ([did] null: a new one, on wall [wall]), a room's settings, how the cable runs, the prices, a room typed by size. */
    data class ENewRoom(val pid: String) : Sheet
    data class EDev(val pid: String, val rid: String, val did: String?, val wall: String? = null) : Sheet
    data class ERoomSet(val pid: String, val rid: String) : Sheet
    data class EMethod(val pid: String) : Sheet
    data class EPrices(val pid: String?) : Sheet
    data class EFree(val pid: String, val fid: String?) : Sheet
    /**
     * A plumber's order: a new room, a fixture ([fid] null: a new one, on wall [wall]), a loose outlet ([ptId] null: a new
     * one), a room's settings, the pipe system, the prices, a room typed by size.
     */
    data class PNewRoom(val pid: String) : Sheet
    data class PFix(val pid: String, val rid: String, val fid: String?, val wall: String? = null) : Sheet
    data class PPoint(val pid: String, val rid: String, val ptId: String?, val wall: String? = null) : Sheet
    data class PRoomSet(val pid: String, val rid: String) : Sheet
    data class PSystem(val pid: String) : Sheet
    data class PPrices(val pid: String?) : Sheet
    data class PFree(val pid: String, val fid: String?) : Sheet
    /** A windows-and-doors order: a new room, the fitting gap, the prices. */
    data class WNewRoom(val pid: String) : Sheet
    data class WGap(val pid: String) : Sheet
    data class WPrices(val pid: String?) : Sheet
    /** The Narx tab: a rate, the fixed price or the lead time ([key] rRun, rTall, fixed, days). */
    data class FPriceField(val pid: String, val key: String) : Sheet
}

/** Everything the screens share: settings, the projects, where each tab is, the open sheet and the toast. */
class App(val settings: Settings, val store: Store, val ctx: android.content.Context) {
    var tab by mutableStateOf(Tab.HOME)
    val stacks: Map<Tab, SnapshotStateList<Route>> = Tab.entries.associateWith { mutableStateListOf<Route>(Route.Root) }
    /** +1 when the last change pushed a page, -1 when it popped one: the slide direction. */
    var dir by mutableStateOf(1)
    var sheet by mutableStateOf<Sheet?>(null)
    var toast by mutableStateOf<ToastMsg?>(null)
    /** The orders list's filter (active, done, all, other trades): kept while an order is opened, changed or deleted. */
    var ordersSeg by mutableStateOf("active")
    /** The room editor's state and undo history. */
    val ops = uz.metrx.app.ui.editor.RoomOps(this)
    /** The Measure page's calculator, kept while the app runs. */
    val calc = uz.metrx.app.ui.measure.MeasureCalc()
    /** Drawings and photos: tools, colours, undo, the photo pickers; the live camera's line. */
    val mk = uz.metrx.app.ui.markup.MarkOps(this)
    val live = uz.metrx.app.ui.markup.LiveLine()
    /** The kitchen designer's undo history and selected unit. */
    val kit = uz.metrx.app.ui.furniture.KitOps()
    /** A room being measured for a room-less piece (room id to furniture id): when it is done, the piece goes in. */
    var placeAfter by mutableStateOf<Pair<String, String>?>(null)

    val stack get() = stacks.getValue(tab)
    val top get() = stack.last()

    /** The same page is not opened twice on top of itself (a double tap). */
    fun push(r: Route) { if (stack.lastOrNull() == r) return; dir = 1; stack.add(r) }
    private var lastAct = 0L
    /** False for a second tap within 600 ms, so a double tap cannot create or save something twice. */
    fun once(): Boolean { val now = android.os.SystemClock.uptimeMillis(); if (now - lastAct < 600) return false; lastAct = now; return true }
    fun replaceTop(r: Route) { dir = 1; stack[stack.lastIndex] = r }
    fun pop(): Boolean { if (stack.size <= 1) return false; dir = -1; stack.removeAt(stack.lastIndex); return true }
    fun popTo(match: (Route) -> Boolean) { dir = -1; while (stack.size > 1 && !match(stack.last())) stack.removeAt(stack.lastIndex) }
    /** Tapping the current tab again goes back to its first page. */
    fun selectTab(t: Tab) {
        if (t == tab) { if (stack.size > 1) { dir = -1; while (stack.size > 1) stack.removeAt(stack.lastIndex) } } else tab = t
    }
    /** Changes the project's tab without adding a page. */
    fun setProjectTab(tabKey: String) { val t = top; if (t is Route.Project) stack[stack.lastIndex] = t.copy(tab = tabKey) }
    /** Changes what the top page shows without moving to another page (project view, editor mode). */
    fun setTop(r: Route) { stack[stack.lastIndex] = r }

    fun say(key: String, vararg v: Pair<String, Any?>, kind: ToastKind = ToastKind.OK, action: String? = null, onAction: (() -> Unit)? = null) {
        toast = ToastMsg(Strings.t(key, settings.lang, if (v.isEmpty()) null else v.toMap()), kind, action?.let { Strings.t(it, settings.lang) }, onAction)
    }
    fun t(key: String, vararg v: Pair<String, Any?>) = Strings.t(key, settings.lang, if (v.isEmpty()) null else v.toMap())

    /** Advanced turned off: its pages (parts and pack, quotes, the workshop's rules and boards) leave every stack. */
    fun dropAdvanced() {
        stacks.values.forEach { st ->
            val keep = st.filter { it !is Route.FCut && it !is Route.FPack && it !is Route.Quote && it != Route.Workshop && it != Route.Materials }
            if (keep.size != st.size) { st.clear(); st.addAll(keep) }
        }
        if (calc.tool == "sheet") calc.tool = "area"
    }

    /** The trade changed (Profile → Soha): the other tabs go back to their first page, so no order of the old trade stays open there. */
    fun dropRole() {
        stacks.forEach { (t, st) -> if (t != tab && st.size > 1) { st.clear(); st.add(Route.Root) } }
    }

    /** Leaves pages of a project or workspace that no longer exists (after a delete). */
    fun dropMissing() {
        stacks.values.forEach { st ->
            val keep = st.filter { r ->
                when (r) {
                    is Route.Project -> store.get(r.id) != null
                    is Route.NewProject -> r.editId == null || store.get(r.editId) != null
                    is Route.Space -> store.get(r.pid)?.floors?.any { it.id == r.wid } == true
                    is Route.Note -> store.get(r.pid)?.floors?.firstOrNull { it.id == r.wid }?.items?.any { it.id == r.iid } == true
                    is Route.Editor -> store.get(r.pid)?.rooms?.any { it.id == r.rid } == true
                    is Route.WallView -> store.get(r.pid)?.rooms?.any { it.id == r.rid } == true
                    is Route.Sketch -> store.get(r.pid)?.floors?.any { it.id == r.wid } == true
                    is Route.Report -> store.get(r.pid) != null
                    is Route.Markup -> if (r.pid == null) settings.shots.any { it.id == r.iid } else store.get(r.pid)?.floors?.any { w -> w.items.any { it.id == r.iid } } == true
                    is Route.Quote -> store.get(r.pid)?.quotes?.any { it.no == r.no } == true
                    is Route.Kitchen -> store.get(r.pid)?.furniture?.any { it.id == r.fid } == true
                    is Route.Wardrobe -> store.get(r.pid)?.furniture?.any { it.id == r.fid } == true
                    is Route.FGallery -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.FSteps -> store.get(r.pid)?.let { p -> r.fid == null || p.furniture.any { it.id == r.fid } } == true
                    is Route.FWhere -> store.get(r.pid) != null
                    is Route.FPlace -> store.get(r.pid)?.let { p -> (r.fid == null || p.furniture.any { it.id == r.fid }) && p.rooms.any { it.id == r.rid } } == true
                    is Route.TGallery -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.TSteps -> store.get(r.pid)?.let { p -> r.lid == null || p.tiles.any { it.id == r.lid } } == true
                    is Route.TView -> store.get(r.pid)?.let { p -> if (r.rid != null) p.rooms.any { it.id == r.rid } else p.tiles.any { it.id == r.lid } } == true
                    is Route.EGallery -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.ESteps -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.EView -> store.get(r.pid)?.let { p -> p.rooms.any { it.id == r.rid } || p.elec.free.any { "free:" + it.id == r.rid } } == true
                    is Route.PGallery -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.PSteps -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.PView -> store.get(r.pid)?.let { p -> p.rooms.any { it.id == r.rid } || p.plumb.free.any { "free:" + it.id == r.rid } } == true
                    is Route.WGallery -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.WPlace -> store.get(r.pid)?.let { p -> r.rid == null || p.rooms.any { it.id == r.rid } } == true
                    is Route.WDesign -> store.get(r.pid)?.win?.item(r.iid) != null
                    is Route.WView -> store.get(r.pid)?.let { p -> p.rooms.any { it.id == r.rid } || p.win.items.any { "free:" + it.id == r.rid } } == true
                    is Route.FCut -> store.get(r.pid) != null
                    is Route.FPack -> store.get(r.pid) != null
                    Route.Root, Route.SettingsMore, Route.Subscription, Route.Workshop, Route.Materials, is Route.Measure, Route.LiveCam -> true
                }
            }
            if (keep.size != st.size) { st.clear(); st.addAll(keep) }
        }
    }
}

val LocalApp = staticCompositionLocalOf<App> { error("App not provided") }
