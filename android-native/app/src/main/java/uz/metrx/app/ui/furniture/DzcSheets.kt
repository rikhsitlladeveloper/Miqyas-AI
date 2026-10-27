package uz.metrx.app.ui.furniture

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import uz.metrx.app.furniture.FCheck
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.checks
import uz.metrx.app.furniture.fillOf
import uz.metrx.app.furniture.wsOf
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Designer C v2: the settings that are not on the drawing ("Qo‘shimcha" at the slider's end): a kitchen's rows' fill,
 * its extras, design and cost; a cabinet's place, sizes, doors, materials and design; one section's inside in detail.
 * The slider does the everyday edits; these keep every older setting within reach.
 */

@Composable
fun DzcMoreSheet(s: Sheet.DzcMore) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val ws = wsOf(f, app.settings.workshop); val mats = app.settings.mats
    val close = { app.sheet = null }
    when {
        s.what == "kitchen" -> GlassSheet(tr("dzc.tool.more"), close) {
            val room = roomOf(p, f)
            val snap = app.settings.angleSnap
            val runs = kRuns(f, room, snap)
            val rt = app.top as? Route.Kitchen
            val run = runs.firstOrNull { it.wall == rt?.wall } ?: runs.firstOrNull()
            if (run != null) {
                Text(runName(f, run), style = ui(15f, 800))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FillPill(tr("kt.low"), fillOf(f, run, false), Modifier.weight(1f))
                    if (run.wall != ISLAND) FillPill(tr("kt.up"), fillOf(f, run, true), Modifier.weight(1f))
                }
                if (room != null && run.wall != ISLAND && !measured(room, snap, run.wall)) Text(tr("kt.noLen", "w" to run.wall), style = ui(13f, 500, G.amberInk, 1.4f),
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp))
            }
            if (f.roomId == null) FreeBanner(p, f)
            if (f.roomId != null && f.free == null) GBtn(tr("ak.title"), { app.sheet = null; app.push(Route.AutoKitchen(p.id, f.roomId, f.id)) }, Btn.SECONDARY, icon = "kitchen",
                height = 46.dp, corner = 16.dp, fontSize = 14.5f)
            val found = checks(f, runs, ws, room?.openings ?: emptyList(), room?.points ?: emptyList()) +
                uz.metrx.app.furniture.boardIssues(f, ws, mats).map { FCheck(it.level, it.key, it.vars, it.mid) }
            ChecksCard(f, found) { id -> f.modules.firstOrNull { it.id == id }?.let { m -> app.sheet = null; rt?.let { r -> if (m.wall != r.wall) app.setTop(r.copy(wall = m.wall)) }; app.dzc(f.id).sel = DSel(m.id) } }
            DesignCard(p, f)
            ExtrasCard(p, f)
            CostCard(p, f, ws, mats)
        }
        s.what == "item" -> GlassSheet(tr("dzc.tool.more"), close) {
            val m = uz.metrx.app.furniture.wardOfF(f) ?: return@GlassSheet
            ItemOptions(p, f, m)
            if (f.roomId == null) FreeBanner(p, f)
            MatStep(p, f, mats)
            DesignCard(p, f)
            CostCard(p, f, ws, mats)
        }
        s.what.startsWith("inside:") -> {
            val m = app.curWard(f) ?: run { app.sheet = null; return }
            val i = s.what.removePrefix("inside:").toIntOrNull()?.coerceIn(0, m.sections.lastIndex) ?: 0
            GlassSheet(tr("dzc.secN", "n" to i + 1) + " · " + tr("dzc.tool.in"), close) {
                InsideStep(p, f, m, i, app.settings.workshop) { }
                if (m.slide == null && m.sections[i].fronts.kind != "open") {
                    HandleButtons(listOf(m), { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, true) } }, { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, false) } },
                        uz.metrx.app.furniture.opensByEdge(f))
                    InnerDrawers(m) { fr -> app.ward(p.id, f.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) } }
                }
            }
        }
        s.what == "place" -> GlassSheet(tr("dzc.tool.place"), close) {
            val m = app.curWard(f) ?: return@GlassSheet
            PlaceStep(p, f, m, WardCtx(p, f, m, app.settings.workshop, app.settings.angleSnap), app.settings.workshop)
        }
        else -> GlassSheet(tr("dzc.tool.more"), close) {
            val m = app.curWard(f) ?: return@GlassSheet
            val cx = WardCtx(p, f, m, app.settings.workshop, app.settings.angleSnap)
            if (f.type == "gorka") GorkaCard(p, f)
            SizeStep(p, f, m, app.settings.workshop)
            if (m.slide != null) SlideDoors(p, f, m, m.slide, app.settings.workshop)
            MatStep(p, f, mats)
            DesignCard(p, f)
            ChecksCard(f, cx.found + uz.metrx.app.furniture.boardIssues(f, ws, mats).filter { it.key == "bz.ck.drawer" }.map { FCheck(it.level, it.key, it.vars, it.mid) }) { }
            CostCard(p, f, ws, mats)
        }
    }
}
