package uz.metrx.app.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import androidx.compose.runtime.mutableStateListOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json

/**
 * The projects on this phone, in SQLite. Each project is one row holding the project as JSON (the same shape as
 * the prototype's state), so the model can grow without table migrations; the JSON carries every field's default.
 *
 * The screens read [projects] (a Compose state list) and change projects through [update]; every change is written
 * to the database shortly after (coalesced per project), in one transaction, off the main thread.
 */
class Store private constructor(context: Context) {
    private val db = Db(context.applicationContext)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    // one thread, so writes run in the order they were asked for (a delete, then its Undo's re-insert)
    private val ioThread = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val io = CoroutineScope(SupervisorJob() + ioThread.asCoroutineDispatcher())
    private val pending = HashMap<String, Job>()
    /** The newest unsaved version of each project, written by its job or by [flush]. */
    private val unsaved = java.util.concurrent.ConcurrentHashMap<String, Project>()

    /** Newest edit first, like the prototype's list. */
    val projects = mutableStateListOf<Project>()

    /**
     * Saved projects that could not be read (skipped, but still in the database): their ids and the pictures and photos
     * their text names ("views/…", "photos/…"), so the cold-start cleanup keeps those files.
     */
    var unreadableIds: Set<String> = emptySet(); private set
    var unreadableFiles: Set<String> = emptySet(); private set

    init {
        val loaded = ArrayList<Project>()
        val badIds = HashSet<String>(); val badFiles = HashSet<String>()
        db.readableDatabase.rawQuery("SELECT id, json FROM projects", null).use { c ->
            while (c.moveToNext()) {
                val text = c.getString(1)
                // trade data left on rooms deleted before deleting took it along goes now (shown nowhere, still counted)
                runCatching { withoutOrphans(json.decodeFromString(Project.serializer(), text)) }
                    .onSuccess { loaded += it }
                    .onFailure {
                        Log.e("METRX", "a saved project could not be read and was skipped", it)
                        badIds += c.getString(0)
                        Regex("(?:views|photos)/[^\"\\\\]+").findAll(text).forEach { m -> badFiles += m.value }
                    }
            }
        }
        unreadableIds = badIds; unreadableFiles = badFiles
        projects.addAll(loaded.sortedByDescending { it.edited })
    }

    fun get(id: String?): Project? = projects.firstOrNull { it.id == id }

    fun add(p: Project) { projects.add(0, p); save(p) }

    /** Change one project; [touch] moves it to the top of the list (edited now). */
    fun update(id: String, touch: Boolean = true, change: (Project) -> Project): Project? {
        val i = projects.indexOfFirst { it.id == id }
        if (i < 0) return null
        var p = change(projects[i])
        if (touch) p = p.copy(edited = System.currentTimeMillis())
        projects[i] = p
        if (touch && i != 0) { projects.removeAt(i); projects.add(0, p) }
        save(p)
        return p
    }

    fun delete(id: String): Pair<Project, Int>? {
        val i = projects.indexOfFirst { it.id == id }
        if (i < 0) return null
        val p = projects.removeAt(i)
        pending.remove(id)?.cancel(); unsaved.remove(id)
        io.launch { db.writableDatabase.delete("projects", "id = ?", arrayOf(id)) }
        return p to i
    }

    /** Puts a deleted project back where it was (Undo). */
    fun restore(p: Project, index: Int) { projects.add(index.coerceIn(0, projects.size), p); save(p, now = true) }

    private fun save(p: Project, now: Boolean = false) {
        pending.remove(p.id)?.cancel()
        unsaved[p.id] = p
        pending[p.id] = io.launch {
            if (!now) delay(250)
            unsaved.remove(p.id, p)
            write(p)
        }
    }

    private fun write(p: Project) {
        val text = json.encodeToString(Project.serializer(), p)
        val w = db.writableDatabase
        w.beginTransaction()
        try {
            w.insertWithOnConflict("projects", null, ContentValues().apply {
                put("id", p.id); put("edited", p.edited); put("json", text)
            }, SQLiteDatabase.CONFLICT_REPLACE)
            w.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.e("METRX", "saving a project failed", e)
        } finally { w.endTransaction() }
    }

    /** Writes every change still waiting, right now (the app is going to the background). */
    fun flush() {
        pending.values.forEach { it.cancel() }; pending.clear()
        val live = projects.map { it.id }.toSet()
        // on the writer's own thread and waited for: after a write it is in the middle of, so an older version cannot land last
        ioThread.submit { unsaved.keys.toList().forEach { id -> unsaved.remove(id)?.let { if (it.id in live) write(it) } } }.get()
    }

    private class Db(context: Context) : SQLiteOpenHelper(context, "metrx.db", null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE projects (id TEXT PRIMARY KEY, edited INTEGER NOT NULL, json TEXT NOT NULL)")
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
    }

    companion object {
        @Volatile private var inst: Store? = null
        fun get(context: Context) = inst ?: synchronized(this) { inst ?: Store(context).also { inst = it } }
    }
}
