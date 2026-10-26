package uz.metrx.app.ui.furniture

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.Project
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Remnant
import uz.metrx.app.furniture.TIER_STD
import uz.metrx.app.furniture.TierPrice
import uz.metrx.app.furniture.tierPrices
import uz.metrx.app.furniture.tierWhat
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigDecimal
import java.math.RoundingMode

/*
 * "3 xil narx" on the Narx tab (Advanced; Joylan ideas, 26 Oct 2026, the mockup's screen 2): Ekonom, Standart and
 * Premium of the same drawing, priced by the workshop's own lists (furniture/PriceTiers.kt), what each changes, and
 * whether the customer's PDF shows all three (Project.tri).
 */

/** A material id's name in the app language (a preset's by its strings key, the workshop's own as typed). */
@Composable
internal fun matNameOf(id: String): String {
    val m = LocalApp.current.settings.mats.firstOrNull { it.id == id } ?: MAT_PRESETS.firstOrNull { it.id == id } ?: return id
    return if (MAT_PRESETS.any { it.id == m.id && it.name == m.name } && uz.metrx.app.core.Strings.has("mp.${m.id}")) tr("mp.${m.id}") else m.name
}

/** A line's value: a strings key, or a material after "#". */
@Composable
internal fun tierValue(v: String): String = if (v.startsWith("#")) matNameOf(v.drop(1)) else tr(v)

@Composable
internal fun TierCard(p: Project, fs: List<Furniture>, rems: List<Remnant>) {
    val app = LocalApp.current
    val s = app.settings
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val tiers by produceState<List<TierPrice>?>(null, p.furniture, p.fprice, s.workshop, s.mats, s.hws, rems) {
        value = withContext(Dispatchers.Default) { runCatching { tierPrices(fs, p.fprice, s.workshop, s.mats, s.hws, rems) }.getOrNull() }
    }
    val f0 = fs.firstOrNull { it.kind == "kitchen" } ?: fs.firstOrNull()
    val kitchen = fs.any { it.kind == "kitchen" }
    val cur = curSuffix(p.currency, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("pt.tiers"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(tr("pt.adv"), style = ui(11f, 800, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(99.dp)).background(G.cobalt.copy(alpha = .1f)).padding(horizontal = 8.dp, vertical = 2.dp))
        }
        Text(tr("pt.sub"), style = ui(12.5f, 400, G.ink2, 1.4f))
        val t = tiers
        if (t == null) Text("…", style = ui(14f, 600, G.ink3))
        else {
            val std = t.firstOrNull { it.tier == TIER_STD }?.price
            t.forEach { tp ->
                val isStd = tp.tier == TIER_STD
                val shape = RoundedCornerShape(16.dp)
                Column(Modifier.fillMaxWidth().clip(shape).background(if (isStd) G.cobalt.copy(alpha = .08f) else G.ink.copy(alpha = .035f))
                    .border(if (isStd) 1.5.dp else 1.dp, if (isStd) G.cobalt.copy(alpha = .5f) else G.rim, shape).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(tr("pt.${tp.tier}"), style = ui(15f, 800), modifier = Modifier.weight(1f))
                        if (isStd) Text(tr("pt.proj"), style = ui(11f, 800, Color.White), modifier = Modifier.clip(RoundedCornerShape(99.dp)).background(G.cobalt).padding(horizontal = 8.dp, vertical = 2.dp))
                        Text(moneyStr(tp.price, p.precision, en) + " " + cur, style = num(15f, 800), maxLines = 1)
                    }
                    val delta = if (isStd || std == null || std.signum() == 0) tr("pt.asDesign") else {
                        val pc = BigDecimal(tp.price - std).multiply(BigDecimal(100)).divide(BigDecimal(std), 0, RoundingMode.HALF_UP).toInt()
                        tr("pt.delta", "v" to (if (pc >= 0) "+" else "−") + kotlin.math.abs(pc))
                    }
                    Text(delta, style = ui(12f, 600, if (isStd) G.cobalt2 else G.ink2))
                    tierWhat(f0, tp.tier, kitchen).forEach { (k, v) ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(tr(k), style = ui(12.5f, 600, G.ink2), modifier = Modifier.weight(.42f))
                            Text(tierValue(v), style = ui(12.5f, 400, G.ink), modifier = Modifier.weight(.58f))
                        }
                    }
                }
            }
        }
        Hairline()
        Toggle(tr("pt.pdf"), p.tri) { app.store.update(p.id) { it.copy(tri = !it.tri) } }
        Text(tr("pt.pdfNote"), style = ui(12f, 400, G.ink2, 1.35f))
    }
}
