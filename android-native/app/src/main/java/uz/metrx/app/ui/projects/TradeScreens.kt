package uz.metrx.app.ui.projects

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.trades.TradeSet
import uz.metrx.app.trades.tradeRows
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The trades' calculator on the estimate tab (trades/Trades.kt): what it worked out from the measured rooms, and the
 * button that puts it into the estimate. Its lines replace the ones it made before; lines typed by hand stay.
 */

/** Puts the calculator's lines into the project's estimate, in place of the ones it made before. */
fun App.applyTrade(p: Project) {
    val r = tradeRows(p.industry, p.rooms, settings.trade, { k, v -> t(k, *v.toList().toTypedArray()) }, settings.angleSnap)
    store.update(p.id) { pr ->
        pr.copy(estimate = pr.estimate.copy(
            materials = pr.estimate.materials.filter { !it.id.startsWith("t-") } + r.mats.map { it.copy(id = "t-" + uz.metrx.app.data.uid()) },
            labor = pr.estimate.labor.filter { !it.id.startsWith("t-") } + r.labor.map { it.copy(id = "t-" + uz.metrx.app.data.uid()) }))
    }
    say("trc.done", "n" to r.mats.size + r.labor.size)
}

@Composable
fun TradeCard(p: Project) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val r = tradeRows(p.industry, p.rooms, app.settings.trade, { k, v -> app.t(k, *v.toList().toTypedArray()) }, app.settings.angleSnap)
    fun d(v: Double?) = v?.let { String.format(java.util.Locale.ROOT, "%.1f", it).replace('.', if (en) '.' else ',') } ?: "0"
    val fact = when (p.industry) {
        "tiler" -> tr("trc.tiler", "a" to d(r.facts["area"]), "b" to (r.facts["boxes"] ?: 0.0).toLong())
        "elec" -> tr("trc.elec", "n" to (r.facts["points"] ?: 0.0).toLong(), "m" to d(r.facts["cable"]))
        "plumb" -> tr("trc.plumb", "n" to (r.facts["points"] ?: 0.0).toLong(), "m" to d(r.facts["pipe"]))
        else -> tr("trc.win", "n" to (r.facts["count"] ?: 0.0).toLong())
    }
    val made = p.estimate.materials.any { it.id.startsWith("t-") } || p.estimate.labor.any { it.id.startsWith("t-") }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("trc.title", "n" to tr("ind.${p.industry}")), style = ui(16f, 800))
        Text(fact, style = num(14.5f, 700))
        Text(tr("trc.body." + p.industry), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (p.rooms.none { uz.metrx.app.geo.ready3D(it, app.settings.angleSnap) }) Text(tr("trc.noRooms"), style = ui(13f, 500, G.amberInk, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (made) "trc.update" else "trc.apply"), { app.applyTrade(p) }, enabled = r.mats.isNotEmpty() || r.labor.isNotEmpty(),
                height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("trc.setB"), { app.sheet = Sheet.TradeCalc(p.id) }, Btn.SECONDARY, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
fun TradeSheet(s: Sheet): Boolean {
    if (s !is Sheet.TradeCalc) return false
    TradeCalcSheet(s.pid)
    return true
}

/** One number of the calculator's settings: a label, the value as typed, its unit. */
private class F(val key: String, val unit: String, val get: (TradeSet) -> String, val set: (TradeSet, String) -> TradeSet)

private fun fieldsOf(trade: String): List<F> = when (trade) {
    "tiler" -> listOf(
        F("tileW", "mm", { it.tileW.toString() }, { t, v -> t.copy(tileW = v.toIntOrNull() ?: t.tileW) }),
        F("tileH", "mm", { it.tileH.toString() }, { t, v -> t.copy(tileH = v.toIntOrNull() ?: t.tileH) }),
        F("boxM2", "m²", { it.boxM2 }, { t, v -> t.copy(boxM2 = v) }),
        F("waste", "%", { it.waste.toString() }, { t, v -> t.copy(waste = v.toIntOrNull() ?: t.waste) }),
        F("wallH", "mm", { it.wallH.toString() }, { t, v -> t.copy(wallH = v.toIntOrNull() ?: 0) }),
        F("pTile", "/m²", { it.pTile }, { t, v -> t.copy(pTile = v) }),
        F("glueKg", "kg/m²", { it.glueKg }, { t, v -> t.copy(glueKg = v) }),
        F("pGlue", "/25 kg", { it.pGlue }, { t, v -> t.copy(pGlue = v) }),
        F("groutKg", "kg/m²", { it.groutKg }, { t, v -> t.copy(groutKg = v) }),
        F("pGrout", "/kg", { it.pGrout }, { t, v -> t.copy(pGrout = v) }),
        F("lTile", "/m²", { it.lTile }, { t, v -> t.copy(lTile = v) }))
    "elec" -> listOf(
        F("lights", "", { it.lights.toString() }, { t, v -> t.copy(lights = v.toIntOrNull() ?: t.lights) }),
        F("pSocket", "", { it.pSocket }, { t, v -> t.copy(pSocket = v) }),
        F("pSwitch", "", { it.pSwitch }, { t, v -> t.copy(pSwitch = v) }),
        F("pLight", "", { it.pLight }, { t, v -> t.copy(pLight = v) }),
        F("pCable", "/m", { it.pCable }, { t, v -> t.copy(pCable = v) }),
        F("pConduit", "/m", { it.pConduit }, { t, v -> t.copy(pConduit = v) }),
        F("pBreaker", "", { it.pBreaker }, { t, v -> t.copy(pBreaker = v) }),
        F("lPoint", "", { it.lPoint }, { t, v -> t.copy(lPoint = v) }))
    "plumb" -> listOf(
        F("pPipe", "/m", { it.pPipe }, { t, v -> t.copy(pPipe = v) }),
        F("pSewer", "/m", { it.pSewer }, { t, v -> t.copy(pSewer = v) }),
        F("pFitting", "", { it.pFitting }, { t, v -> t.copy(pFitting = v) }),
        F("pTap", "", { it.pTap }, { t, v -> t.copy(pTap = v) }),
        F("lPlumb", "", { it.lPlumb }, { t, v -> t.copy(lPlumb = v) }))
    else -> listOf(
        F("pWinM2", "/m²", { it.pWinM2 }, { t, v -> t.copy(pWinM2 = v) }),
        F("pDoorM2", "/m²", { it.pDoorM2 }, { t, v -> t.copy(pDoorM2 = v) }),
        F("pSillM", "/m", { it.pSillM }, { t, v -> t.copy(pSillM = v) }),
        F("pRevealM", "/m", { it.pRevealM }, { t, v -> t.copy(pRevealM = v) }),
        F("lWin", "", { it.lWin }, { t, v -> t.copy(lWin = v) }))
}

@Composable
private fun TradeCalcSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val fields = fieldsOf(p.industry)
    val start = app.settings.trade
    // the fields keep what is typed; the numbers are read when saving, so the cursor never jumps
    var texts by rememberSaveable { mutableStateOf(fields.associate { it.key to it.get(start) }) }
    var floorOn by rememberSaveable { mutableStateOf(start.floor) }
    fun save() {
        val t = fields.fold(start.copy(floor = floorOn)) { acc, f -> f.set(acc, texts[f.key].orEmpty()) }
        app.settings.setTradeSet(t); app.sheet = null; app.applyTrade(app.store.get(pid) ?: p)
    }
    GlassSheet(tr("trc.set"), { app.sheet = null }, footer = { GBtn(tr("trc.saveApply"), ::save) }) {
        if (p.industry == "tiler") {
            Text(tr("trc.surfaces"), style = ui(15f, 700))
            Seg(listOf("1" to tr("trc.floorOn"), "0" to tr("trc.floorOff")), if (floorOn) "1" else "0") { floorOn = it == "1" }
        }
        fields.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { f ->
                    GField(tr("trf.${f.key}"), texts[f.key].orEmpty(), { v -> texts = texts + (f.key to v.filter { c -> c.isDigit() || c == ',' || c == '.' }.replace(',', '.')) }, "0",
                        number = true, labelRight = f.unit.ifEmpty { null }, modifier = Modifier.weight(1f))
                }
                if (row.size == 1) androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
            }
        }
        Text(tr("trc.note"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}
