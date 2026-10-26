package uz.metrx.app.ui.ux

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The toasts' and bottom bars' Undo (UX upgrades §1, §3), e.g. "Namuna o‘chirildi" → "Ortga qaytarish". */
class UndoStackTest {
    @Test fun toastUndoTakesBackItsOwnActionEvenAfterNewerOnes() {
        val s = UndoStack(); val log = mutableListOf<String>()
        val sample = s.push("Namuna o‘chirildi") { log += "sample" }
        s.push("Eshik o‘ngga") { log += "door" }
        assertTrue(s.undo(sample))
        assertEquals(listOf("sample"), log)
        assertEquals(1, s.size)
    }

    @Test fun aDoubleTapRunsOnce() {
        val s = UndoStack(); var n = 0
        val e = s.push("Namuna o‘chirildi") { n++ }
        assertTrue(s.undo(e)); assertFalse(s.undo(e))
        assertEquals(1, n)
    }

    @Test fun sameWordsStayTwoActions() {
        // the sample deleted, put back and deleted again: each toast undoes its own deletion
        val s = UndoStack(); val log = mutableListOf<Int>()
        val first = s.push("Namuna o‘chirildi") { log += 1 }
        val second = s.push("Namuna o‘chirildi") { log += 2 }
        assertTrue(s.undo(second)); assertTrue(s.undo(first))
        assertEquals(listOf(2, 1), log)
    }

    @Test fun bottomBarAndToastNeverBothRun() {
        val s = UndoStack(); var n = 0
        val e = s.push("Namuna o‘chirildi") { n++ }
        assertEquals(e, s.undoLast())
        assertFalse(s.undo(e))
        assertNull(s.undoLast())
        assertEquals(1, n)
    }

    @Test fun forgottenSampleUndoDoesNothing() {
        // the sample made again (Profile → "Maslahatlarni qayta ko‘rsatish"): the old deletion's Undo must not add a second one
        val s = UndoStack(); var n = 0
        val e = s.push("Namuna o‘chirildi", tag = "sample") { n++ }
        val other = s.push("Eshik o‘ngga") {}
        s.forget("sample")
        assertFalse(s.undo(e))
        assertEquals(0, n)
        assertTrue(s.undo(other))
    }

    @Test fun keepsTheNewestOnly() {
        val s = UndoStack(max = 3); val log = mutableListOf<Int>()
        val oldest = s.push("1") { log += 1 }
        (2..4).forEach { i -> s.push("$i") { log += i } }
        assertEquals(3, s.size)
        assertFalse(s.undo(oldest))
        s.undoLast(); s.undoLast(); s.undoLast()
        assertEquals(listOf(4, 3, 2), log)
        assertFalse(s.isNotEmpty())
    }
}
