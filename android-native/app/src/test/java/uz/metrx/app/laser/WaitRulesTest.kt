package uz.metrx.app.laser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet

/** When a "Lazer" button waiting for the real laser stops waiting (laser/LaserRouter.kt WaitRules). */
class WaitRulesTest {
    private val plan = Route.Editor("p1", "r1", "plan")
    private val d3 = Route.Editor("p1", "r1", "3d")

    @Test fun theEditorsPlanAnd3dAreOnePage() {
        assertEquals(WaitRules.pageKey(plan), WaitRules.pageKey(d3))
        assertTrue(WaitRules.keeps(plan, null, d3, null))
        assertTrue(WaitRules.keeps(d3, null, plan, null))
    }

    @Test fun anotherRoomOrPageIsNot() {
        assertFalse(WaitRules.keeps(plan, null, Route.Editor("p1", "r2"), null))
        assertFalse(WaitRules.keeps(plan, null, Route.Root, null))
        assertFalse(WaitRules.keeps(Route.Markup("p1", "i1"), null, Route.Markup("p1", "i2"), null))
    }

    @Test fun aProjectsViewsAndTabsAreOnePage() {
        assertTrue(WaitRules.keeps(Route.Project("p1"), null, Route.Project("p1", tab = "estimate", view = "3d", floor = "f2"), null))
        assertFalse(WaitRules.keeps(Route.Project("p1"), null, Route.Project("p2"), null))
    }

    @Test fun aButtonPressedInASheetStopsWhenTheSheetCloses() {
        val top = Route.FPlace("p1", "f1", "r1")
        val point = Sheet.PointForm("p1", "r1", "A")
        assertTrue(WaitRules.keeps(top, point, top, point))
        // closed, or another sheet in its place
        assertFalse(WaitRules.keeps(top, point, top, null))
        assertFalse(WaitRules.keeps(top, point, top, Sheet.Device))
        val dim = Sheet.MkDim("e1")
        val mk = Route.Markup(null, "i1")
        assertFalse(WaitRules.keeps(mk, dim, mk, null))
        assertFalse(WaitRules.keeps(mk, dim, mk, Sheet.MkDim("e2")))
    }

    @Test fun aButtonOnThePageKeepsWaitingWhenASheetOpensOverIt() {
        assertTrue(WaitRules.keeps(plan, null, plan, Sheet.Device))
        assertTrue(WaitRules.keeps(plan, null, plan, Sheet.Measure("p1", "r1", "A")))
    }
}
