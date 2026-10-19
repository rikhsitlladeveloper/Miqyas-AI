package uz.metrx.app.ui.furniture

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.TextMeasurer
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.outerH
import uz.metrx.app.ui.editor.INK
import uz.metrx.app.ui.theme.Theme

/** A front drawing for a document (furniture plan section 10): [wall] null for a wardrobe; its viewBox; how to draw it. */
class FrontFig(val wall: String?, val vw: Float, val vh: Float, val draw: DrawScope.(TextMeasurer) -> Unit)

/** The fronts of [f] as the documents show them: each kitchen wall (and the island), or the wardrobe, with sizes. */
fun frontFigures(f: Furniture, room: Room?, ws: Workshop, mats: List<Mat>): List<FrontFig> {
    if (f.kind == "wardrobe") {
        val m = wardOf(f) ?: return emptyList()
        val lay = KLay(m.w, outerH(m, ws), 360f, true)
        return listOf(FrontFig(null, lay.vw, lay.vh) { tm ->
            Theme.onPaper {
                val front = hex(mats.firstOrNull { it.id == f.mats.front }?.rgb ?: "#CDBFAE")
                val carcass = hex(mats.firstOrNull { it.id == f.mats.carcass }?.rgb ?: "#F5F5F2")
                drawLine(INK, Offset(lay.x0 - 10f, lay.yF), Offset(lay.x(m.w) + 10f, lay.yF), 2f)
                drawWard(lay, m, m.x, ws, carcass, front, -1, true, emptyMap(), tm)
                var acc = 0
                wardDims(lay, listOf(0) + m.sections.map { s -> acc += s.w; acc }, m.w, outerH(m, ws), 0, tm)
            }
        })
    }
    return kRuns(f, room, true).filter { r -> f.modules.any { it.wall == r.wall } }.map { run ->
        val lay = KLay(runLen(f, run), roomH(room), 360f, true, runExt(f, run))
        FrontFig(run.wall.takeIf { it != ISLAND } ?: ISLAND, lay.vw, lay.vh) { tm -> Theme.onPaper { drawRun(lay, f, run, room, ws, mats, null, emptyMap(), tm) } }
    }
}
