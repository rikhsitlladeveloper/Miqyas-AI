package uz.metrx.app.ui.furniture

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.furniture.DT_LEGS
import uz.metrx.app.furniture.DT_SEATS
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.GK_PANELS
import uz.metrx.app.furniture.GK_TVS
import uz.metrx.app.furniture.LOOK_FABRICS
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.gorkaGlass
import uz.metrx.app.furniture.gorkaRoles
import uz.metrx.app.furniture.gorkaVals
import uz.metrx.app.furniture.pieceResized
import uz.metrx.app.furniture.seatsOf
import uz.metrx.app.furniture.tvFits
import uz.metrx.app.furniture.tvSize
import uz.metrx.app.furniture.withGorkaGlass
import uz.metrx.app.furniture.withGorkaPanel
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.worktopDecor
import uz.metrx.app.furniture.worktopFor
import uz.metrx.app.furniture.worktopKind
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The gorka's and the big dining table's own options (modern 3D part 6a; the rules in furniture/Gorka.kt). The gorka
 * has the wardrobe designer for its boxes (sections, doors, inside, materials) and this card over it: two towers or
 * one, the bridge, glass doors, LED, the cornice, the TV panel's facing and the TV. The big table has the short
 * designer of tables with its seats, legs, top and the chairs' fabric.
 */

/** A row of chips, [cur] the one on. */
@Composable
private fun ChipRow(items: List<Pair<String, String>>, cur: String, onPick: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        items.forEach { (k, label) -> Chip(label, k == cur) { onPick(k) } }
    }
}

/** The gorka's card in its designer. */
@Composable
internal fun GorkaCard(p: Project, f: Furniture) {
    val app = LocalApp.current
    val ws = app.settings.workshop
    val r = gorkaRoles(f) ?: return
    val v = gorkaVals(f, ws)
    fun change(fn: (Furniture) -> Furniture) { app.kit.change(app, p.id, f.id, fn) }
    // the towers and the bridge build it again (the boxes' own changes are reset, as with new sizes)
    fun rebuild(k: String, x: Int) = change { pieceResized(it, mapOf(k to x), ws) }
    val panel = r.panel
    val pn = panel?.opt?.panel?.ifEmpty { "stone" } ?: "stone"
    val tv = panel?.opt?.tv?.takeIf { it > 0 } ?: 65
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("gk.title"), style = ui(15.5f, 800))
        Text(tr("gk.towers"), style = ui(14.5f, 700))
        Seg(listOf("2" to tr("gk.towers.2"), "1" to tr("gk.towers.1")), if (v["one"] == 1) "1" else "2") { k -> if ((k == "1") != (v["one"] == 1)) rebuild("one", if (k == "1") 1 else 0) }
        Toggle(tr("gk.bridge"), v["nobr"] != 1) { rebuild("nobr", if (v["nobr"] == 1) 0 else 1) }
        Text(tr("gk.rebuild"), style = ui(12f, 400, G.ink2, 1.4f))
        Toggle(tr("gk.glass"), gorkaGlass(f)) { change { withGorkaGlass(it, !gorkaGlass(it)) } }
        Toggle(tr("gk.led"), f.look?.led == true) { change { withLook(it) { l -> l.copy(led = !l.led) } } }
        Toggle(tr("gk.cornice"), f.look?.crown == "cornice") { change { withLook(it) { l -> l.copy(crown = if (l.crown == "cornice") "" else "cornice") } } }
        Text(tr("gk.panelT"), style = ui(14.5f, 700))
        Seg(GK_PANELS.map { it to tr("gk.pn.$it") }, pn, lines = 2) { k -> change { withGorkaPanel(it, panel = k) } }
        Text(tr("gk.pn.$pn.s"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (pn == "stone") {
            val cur = worktopDecor(f.mats.top).takeIf { it in setOf("marble", "onyx", "dark") } ?: "marble"
            ChipRow(listOf("marble", "onyx", "dark").map { it to tr("lk.st.$it") }, cur) { k -> change { g -> withLook(g) { it }.let { x -> x.copy(mats = x.mats.copy(top = worktopFor("stone", k))) } } }
        }
        Text(tr("gk.tv"), style = ui(14.5f, 700))
        ChipRow(GK_TVS.map { "$it" to tr("gk.tv.$it") }, "$tv") { k -> change { withGorkaPanel(it, tv = k.toInt()) } }
        if (panel != null) {
            val fits = tvFits(f)
            Text(tr(if (fits) "gk.tvFits" else "gk.tvWide", "t" to tvSize(tv).first, "p" to panel.w), style = ui(12.5f, 400, if (fits) G.ink2 else G.err, 1.4f))
        }
    }
}

/** The big table's options in the short designer: its sizes, seats, legs, top and the chairs' fabric. */
@Composable
internal fun BigTableOptions(p: Project, f: Furniture, m: Module) {
    val app = LocalApp.current
    val ws = app.settings.workshop
    val o = m.opt ?: return
    fun change(fn: (Furniture) -> Furniture) { app.kit.change(app, p.id, f.id, fn) }
    fun set(k: String, x: Int) = change { pieceResized(it, mapOf(k to x), ws) }
    listOf("w" to "wd.w", "d" to "wd.d", "h" to "fz.wH").forEach { (k, label) ->
        val now = when (k) { "w" -> m.w; "d" -> m.d; else -> m.h }
        FValRow(tr(label), "$now " + tr("u.mm")) { app.sheet = Sheet.IField(p.id, f.id, m.id, k) }
    }
    Text(tr("dt.st"), style = ui(14.5f, 700))
    Seg(DT_SEATS.map { "$it" to tr("dt.st.$it") }, "${o.seats}") { k -> set("st", DT_SEATS.indexOf(k.toInt())) }
    val seated = seatsOf(m)
    Text(if (seated < o.seats) tr("dt.short", "n" to o.seats, "m" to seated) else tr("dt.seated", "n" to seated), style = ui(12.5f, 400, if (seated < o.seats) G.err else G.ink2, 1.4f))
    Text(tr("fb.lg"), style = ui(14.5f, 700))
    Seg(DT_LEGS.map { it to tr("fb.lg.$it") }, o.legs, lines = 2) { k -> set("lg", DT_LEGS.indexOf(k)) }
    val tk = if (worktopKind(f.mats.top) == "wood") "wood" else "stone"
    Text(tr("dt.tk"), style = ui(14.5f, 700))
    Seg(listOf("stone" to tr("dt.tk.stone"), "wood" to tr("dt.tk.wood")), tk) { k -> set("tk", if (k == "wood") 1 else 0) }
    val decors = if (tk == "wood") listOf("halifax", "craft").map { it to tr("lk.w.$it") } else listOf("marble", "onyx", "dark").map { it to tr("lk.st.$it") }
    ChipRow(decors, worktopDecor(f.mats.top)) { k -> change { g -> withLook(g) { it }.let { x -> x.copy(mats = x.mats.copy(top = worktopFor(tk, k))) } } }
    Text(tr("dt.fabric"), style = ui(14.5f, 700))
    ChipRow(LOOK_FABRICS.map { it.key to tr("lk.fab.${it.key}") }, f.look?.fabric ?: "") { k -> change { withLook(it) { l -> l.copy(fabric = k) } } }
    Text(tr("dt.chairsNote"), style = ui(12f, 400, G.ink2, 1.4f))
}
