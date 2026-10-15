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
}

/** Everything the screens share: settings, the projects, where each tab is, the open sheet and the toast. */
class App(val settings: Settings, val store: Store, val ctx: android.content.Context) {
    var tab by mutableStateOf(Tab.HOME)
    val stacks: Map<Tab, SnapshotStateList<Route>> = Tab.entries.associateWith { mutableStateListOf<Route>(Route.Root) }
    /** +1 when the last change pushed a page, -1 when it popped one: the slide direction. */
    var dir by mutableStateOf(1)
    var sheet by mutableStateOf<Sheet?>(null)
    var toast by mutableStateOf<ToastMsg?>(null)
    /** The room editor's state and undo history. */
    val ops = uz.metrx.app.ui.editor.RoomOps(this)
    /** The Measure page's calculator, kept while the app runs. */
    val calc = uz.metrx.app.ui.measure.MeasureCalc()
    /** Drawings and photos: tools, colours, undo, the photo pickers; the live camera's line. */
    val mk = uz.metrx.app.ui.markup.MarkOps(this)
    val live = uz.metrx.app.ui.markup.LiveLine()

    val stack get() = stacks.getValue(tab)
    val top get() = stack.last()

    fun push(r: Route) { dir = 1; stack.add(r) }
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
                    Route.Root, Route.SettingsMore, Route.Subscription, is Route.Measure, Route.LiveCam -> true
                }
            }
            if (keep.size != st.size) { st.clear(); st.addAll(keep) }
        }
    }
}

val LocalApp = staticCompositionLocalOf<App> { error("App not provided") }
