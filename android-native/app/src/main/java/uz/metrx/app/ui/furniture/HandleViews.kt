package uz.metrx.app.ui.furniture

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.furniture.HFront
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.blockH
import uz.metrx.app.furniture.handleFronts
import uz.metrx.app.furniture.handleSplit
import uz.metrx.app.furniture.hasHandle
import uz.metrx.app.furniture.legsOf
import uz.metrx.app.furniture.wardBase
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.roundToInt

/*
 * Handles per door and per drawer (25 Oct 2026): the fronts of a drawing as tap targets (each one's handle on or off,
 * read out by TalkBack), the "Hammasiga" / "Hech biriga" buttons and the count line. The rules are in
 * furniture/Handles.kt.
 */

/** A front's place in a drawing, mm: left, bottom, right, top. */
internal class FrontBox(val f: HFront, val x0: Int, val y0: Int, val x1: Int, val y1: Int)

/** Where each front of a wardrobe-engine box is as [drawWard] draws it (the box from its legs' or plinth's bottom). */
internal fun wardFrontBoxes(m: Module, ws: Workshop): List<FrontBox> {
    val z0 = legsOf(m, ws) + m.elev
    val base = wardBase(m)
    val g = ws.gap10 / 10
    val starts = m.sections.runningFold(m.x) { a, s -> a + s.w }
    // a drawer behind the doors is not on the doors' picture: it has its row ([InnerDrawers])
    return handleFronts(m).filter { !it.inner }.mapNotNull { f ->
        val s = m.sections.getOrNull(f.sec) ?: return@mapNotNull null
        val a = starts[f.sec]
        if (f.key.contains(":d")) {
            val x = s.inserts.firstOrNull { it.kind == "drawer" && "s${f.sec}:d${it.pos}" == f.key } ?: return@mapNotNull null
            val y0 = z0 + base + ws.t + x.pos
            FrontBox(f, a + 2, y0, a + s.w - 2, y0 + blockH(x))
        } else {
            val n = s.fronts.n.coerceAtLeast(1)
            val j = f.key.substringAfter(":f").toIntOrNull() ?: 0
            val fw = (s.w - s.blind - g * (n + 1)) / n
            val x0 = a + g + j * (fw + g)
            FrontBox(f, x0, z0 + base + g, x0 + fw, z0 + m.h - g)
        }
    }
}

/** Where each front of a kitchen unit is as [drawUnit] draws it, the unit at 0 from its own bottom: doors left to right, drawers top down. */
internal fun unitFrontBoxes(m: Module, ws: Workshop): List<FrontBox> {
    val g = ws.gap10 / 10
    val fr = handleFronts(m).filter { it.sec < 0 }
    val n = fr.size.coerceAtLeast(1)
    return fr.mapIndexed { i, f ->
        if (m.fronts.kind == "drawer") {
            val fh = (m.h - g * (n + 1)) / n
            val top = m.h - g - i * (fh + g)
            FrontBox(f, g, top - fh, m.w - g, top)
        } else {
            val fw = (m.w - g * (n + 1)) / n
            val x0 = g + i * (fw + g)
            FrontBox(f, x0, g, x0 + fw, m.h - g)
        }
    }
}

/** A front's name for TalkBack and the tests: "2-bo‘lim, 1-eshik" or "3-tortma". */
@Composable
internal fun frontName(m: Module, f: HFront): String {
    val fr = handleFronts(m).filter { it.sec == f.sec }
    if (f.sec < 0) return tr(if (f.drawer) "hd.uDrawer" else "hd.uDoor", "n" to fr.indexOf(f) + 1)
    val drawers = f.key.contains(":d")
    return tr(if (drawers) "hd.drawer" else "hd.door", "s" to f.sec + 1, "n" to fr.filter { it.key.contains(":d") == drawers }.indexOf(f) + 1)
}

/**
 * The fronts of a drawing [lay] wide ([ox] mm at its left) as tap targets over it, in the drawing's box: each toggles
 * its handle; a glass door has none to toggle. [edge]: the piece opens by its edge, not by a push latch.
 */
@Composable
internal fun FrontTargets(lay: KLay, ox: Int, m: Module, boxes: List<FrontBox>, onTap: (HFront) -> Unit, edge: Boolean = false) {
    val d = LocalDensity.current
    BoxWithConstraints {
        val k = constraints.maxWidth / lay.vw
        boxes.forEach { b ->
            val l = lay.x(b.x0 - ox) * k; val r = lay.x(b.x1 - ox) * k
            val t = lay.y(b.y1) * k; val bt = lay.y(b.y0) * k
            if (r - l < 2f || bt - t < 2f) return@forEach
            val name = frontName(m, b.f)
            val on = hasHandle(m, b.f.key)
            val state = tr(when { b.f.glass -> "hd.glass"; on -> "hd.on"; edge -> "hd.edge"; else -> "hd.off" })
            Box(Modifier.offset { IntOffset(l.roundToInt(), t.roundToInt()) }.size(with(d) { (r - l).toDp() }, with(d) { (bt - t).toDp() })
                .testTag("front:${b.f.key}")
                .semantics { contentDescription = name; stateDescription = state; if (!b.f.glass) role = Role.Switch }
                .let { if (b.f.glass) it else it.clickable { onTap(b.f) } })
        }
    }
}

/** "Hammasiga" / "Hech biriga" for the handles, and how many fronts have one; [edge]: the rest open by the edge, not a push. */
@Composable
internal fun HandleButtons(ms: List<Module>, onAll: () -> Unit, onNone: () -> Unit, edge: Boolean = false) {
    val (a, b) = ms.fold(0 to 0) { acc, m -> handleSplit(m).let { acc.first + it.first to acc.second + it.second } }
    if (a + b == 0) return
    Text(tr("hd.title"), style = ui(14.5f, 700))
    Text(tr(if (edge) "hd.countE" else "hd.count", "a" to a, "b" to b), style = ui(12.5f, 500, G.ink2, 1.4f))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        GBtn(tr("hd.all"), onAll, Btn.SECONDARY, enabled = b > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        GBtn(tr("hd.none"), onNone, Btn.SECONDARY, enabled = a > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
    }
}

/**
 * The drawers behind the doors (hinged or sliding), hidden by them on the doors' picture: a row of chips, one a drawer,
 * each tapped to give it a handle or take it away (founder's decision, 25 Oct 2026). Nothing when the box has none.
 */
@Composable
internal fun InnerDrawers(m: Module, onTap: (HFront) -> Unit) {
    val inner = handleFronts(m).filter { it.inner }
    if (inner.isEmpty()) return
    Text(tr("hd.inner"), style = ui(13.5f, 700))
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        inner.forEach { fr ->
            val on = hasHandle(m, fr.key)
            Box(Modifier.testTag("front:${fr.key}")) { Chip(frontName(m, fr) + " · " + tr(if (on) "hd.yes" else "hd.no"), on) { onTap(fr) } }
        }
    }
}
