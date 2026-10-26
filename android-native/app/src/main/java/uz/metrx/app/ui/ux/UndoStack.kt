package uz.metrx.app.ui.ux

import androidx.compose.runtime.mutableStateListOf

/** One action that can be taken back. Equal only to itself: two actions with the same words stay two. */
class UndoEntry(val text: String, val tag: String?, val run: () -> Unit)

/**
 * The last actions that can be undone (UX upgrades §1, §3): a toast's "Ortga qaytarish" takes back its own action,
 * the bottom bars' Undo the newest one; each action runs once, whichever asks first.
 */
class UndoStack(private val max: Int = 20) {
    private val list = mutableStateListOf<UndoEntry>()

    val size: Int get() = list.size
    fun isNotEmpty() = list.isNotEmpty()

    fun push(text: String, tag: String? = null, run: () -> Unit): UndoEntry {
        val e = UndoEntry(text, tag, run)
        list.add(e)
        while (list.size > max) list.removeAt(0)
        return e
    }

    /** Takes back [e] unless it was already (or was forgotten); true when it ran. */
    fun undo(e: UndoEntry): Boolean {
        if (!list.remove(e)) return false
        e.run()
        return true
    }

    /** Takes back the newest action; null when there is none. */
    fun undoLast(): UndoEntry? {
        val e = list.removeLastOrNull() ?: return null
        e.run()
        return e
    }

    /** Forgets the actions tagged [tag]: what they would put back has changed since. */
    fun forget(tag: String) { list.removeAll { it.tag == tag } }
}
