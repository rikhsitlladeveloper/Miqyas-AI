package uz.metrx.app.ui.ux

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.math.BigInteger

/*
 * The designers' frame (UX upgrades §1, §2, §4): the header with Back, the piece's name and the menu, the compact
 * progress and the price chip; at the bottom "Narxni ko‘rish", a small Undo (Redo once something was undone) and 2D/3D.
 */

/** The header of a kitchen, wardrobe, bed… designer. */
@Composable
fun DesignerTop(p: Project, f: Furniture, sub: String) {
    val app = LocalApp.current
    val lang = LocalLang.current
    UxTop(dn(f.name, lang), { app.pop() }, eyebrow = sub, sample = p.sample, right = {
        Box(Modifier.size(46.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button, onClickLabel = tr("common.menu")) {
            app.sheet = Sheet.FMenu(p.id, f.id)
        }, contentAlignment = Alignment.Center) { MIcon("more", G.ink, 20.dp, 2f) }
    }) {
        ProgressRow(p, compact = true)
        PieceChip(p, f)
    }
}

/** The piece's price chip: simple mode grey "≈ … (taxminiy)", Advanced the exact price and the cost (§4). Tap: the price screen. */
@Composable
private fun PieceChip(p: Project, f: Furniture) {
    val app = LocalApp.current
    val s = app.settings
    if (f.modules.isEmpty()) return
    // a fixed order price has no price a piece: the piece by the margin
    val fp = p.fprice.let { if (it.mode == "fixed") it.copy(mode = "margin") else it }
    val pr = remember(f, fp, s.workshop, s.mats, s.hws) { priceOf(listOf(f), fp, s.workshop, s.mats, s.hws) }
    val price = pr.lines.firstOrNull { it.key == f.id }?.amount ?: pr.price
    if (price.signum() <= 0) return
    val text = if (s.advanced) {
        val cost = remember(f, s.workshop, s.mats, s.hws) { uz.metrx.app.furniture.costOf(listOf(f), uz.metrx.app.furniture.wsOf(f, s.workshop), s.mats, s.hws, order = false).total }
        app.moneyText(p, price) + " · " + tr("fp.cost") + " " + app.moneyText(p, cost)
    } else tr("ux.approx", "v" to app.moneyText(p, price.add(BigInteger.valueOf(500)).divide(BigInteger.valueOf(1000)).multiply(BigInteger.valueOf(1000))))
    Row(Modifier.clip(RoundedCornerShape(12.dp)).background(if (s.advanced) G.blueWash else G.ink.copy(alpha = .05f))
        .clickable(role = Role.Button) { app.push(Route.FPrice(p.id)) }.padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        MIcon("coin", if (s.advanced) G.cobalt2 else G.ink3, 15.dp, 2f)
        Text(text, style = ui(12.5f, if (s.advanced) 700 else 600, if (s.advanced) G.ink else G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The designer's bottom bar: Undo (and Redo), 2D/3D, and "Narxni ko‘rish" (it marks the design step done). */
@Composable
fun DesignerBar(p: Project, f: Furniture, d3: Boolean, onD3: (Boolean) -> Unit) {
    val app = LocalApp.current
    val kit = app.kit
    UxBar(tr("ux.a.price"), "coin", {
        app.haptic(Hap.TICK)
        if (!p.designed) app.store.update(p.id, touch = false) { it.copy(designed = true) }
        app.push(Route.FPrice(p.id))
    }, onUndo = { kit.undo(app, p.id, f.id); app.haptic(Hap.TICK) }, canUndo = kit.canUndo(f.id),
        onRedo = { kit.redo(app, p.id, f.id); app.haptic(Hap.TICK) }, canRedo = kit.canRedo(f.id),
        seg = { Seg2D3D(d3, onD3) }, undoCoach = "designer")
}

/** A quick action in a designer (door, handle, style…): its toast with "Ortga qaytarish" that undoes it (§3). */
object QuickOps {
fun uz.metrx.app.ui.App.quick(pid: String, fid: String, text: String) {
    toast = uz.metrx.app.ui.components.ToastMsg(text, uz.metrx.app.ui.components.ToastKind.OK, t("ux.undo"), onAction = { kit.undo(this, pid, fid); haptic(Hap.TICK) })
    haptic(Hap.TICK)
}
}
