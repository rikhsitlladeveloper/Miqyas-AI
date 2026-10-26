package uz.metrx.app.ui.ux

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import uz.metrx.app.data.Project
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The bars of the UX upgrades (§1, §2, §12): an almost solid header with Back and the order's name (it wraps, never cut)
 * and a bottom action bar in thumb reach with one big next-step button, a small Undo and, in the designers, 2D/3D; the
 * progress bar Xona → Mebel → Dizayn → Narx → PDF; the order cards' 5-segment line.
 */

/** The bars' fill: about 95 % of the glass colour, so the drawing behind never shows through the words (§12). */
private fun barFill() = G.sheet(.95f)

/** A bottom bar tells the toast where it is, so the toast sits just above it (§3). */
fun barSpotModifier(): Modifier = Modifier.composed {
    val app = LocalApp.current
    val key = remember { "bar" + System.nanoTime() }
    DisposableEffect(key) { onDispose { app.bars.remove(key) } }
    Modifier.onGloballyPositioned { c ->
        val h = (c.findRootCoordinates().size.height - c.boundsInRoot().top).toInt()
        if (app.bars[key] != h) app.bars[key] = h
    }
}

/** Where a coach mark points (§11): the target's place on screen, under [key]. */
fun Modifier.coachSpot(key: String): Modifier = composed {
    val app = LocalApp.current
    // kept after the target leaves (a modifier rebuilt on every recomposition would otherwise make it flicker); the
    // coach mark reads it only while its own screen is on top
    this.onGloballyPositioned { c -> val r = c.boundsInRoot(); if (!r.isEmpty && app.coach[key] != r) app.coach[key] = r }
}

/** The header: Back, a small line above the title (with the NAMUNA badge), the title on up to 3 lines, [right] buttons, and [below]. */
@Composable
fun UxTop(title: String, onBack: () -> Unit, eyebrow: String? = null, sample: Boolean = false, right: @Composable RowScope.() -> Unit = {},
          below: (@Composable ColumnScope.() -> Unit)? = null) {
    val haze = LocalHaze.current
    Column(Modifier.fillMaxWidth().glassBlur(haze, barFill(), 20.dp).background(barFill())
        .drawBehind { drawRect(G.ink.copy(alpha = .08f), Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) }
        .statusBarsPadding().padding(start = 8.dp, end = 10.dp, top = 6.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = tr("nt.back"), onClick = onBack)
                .semantics { contentDescription = "back" }, contentAlignment = Alignment.Center) { MIcon("back", G.ink, 24.dp, 2.2f) }
            Column(Modifier.weight(1f).padding(top = if (eyebrow != null || sample) 2.dp else 11.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (eyebrow != null || sample) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (sample) SampleBadge()
                    if (eyebrow != null) Text(eyebrow, style = ui(12.5f, 600, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                // the order's name wraps and is never cut (§1)
                Text(title, style = ui(18.5f, 800, G.ink, 1.2f))
            }
            Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically, content = right)
        }
        if (below != null) Column(Modifier.padding(start = 6.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = below)
    }
}

/** The grey "NAMUNA" badge of the sample order (§11). */
@Composable
fun SampleBadge() {
    Text(tr("ux.sample").uppercase(), style = ui(11f, 800, G.amberInk, spacing = .04f), maxLines = 1,
        modifier = Modifier.clip(RoundedCornerShape(7.dp)).background(G.amberWash).padding(horizontal = 7.dp, vertical = 2.dp))
}

/** A round 48 dp button of the bars. */
@Composable
fun BarIcon(icon: String, label: String, on: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f))
        .clickable(role = Role.Button, onClickLabel = label) { if (on) onClick() }.semantics { contentDescription = label },
        contentAlignment = Alignment.Center) { UxIcon(icon, if (on) G.ink else G.ink3.copy(alpha = .45f), 22.dp, 2.2f) }
}

/**
 * The bottom action bar (§1): [onUndo] the small Undo (and [onRedo] beside it once something was undone), [seg] the
 * designers' 2D/3D switch, the one big next-step button, and [below] a small link under it (the price screen's "Boshqa…").
 */
@Composable
fun UxBar(main: String, mainIcon: String?, onMain: () -> Unit, onUndo: (() -> Unit)?, canUndo: Boolean, onRedo: (() -> Unit)? = null, canRedo: Boolean = false,
          seg: (@Composable () -> Unit)? = null, mainEnabled: Boolean = true, coach: String? = null, undoCoach: String? = null, mainColor: Color? = null,
          below: (@Composable () -> Unit)? = null) {
    val haze = LocalHaze.current
    val pulse = remember { Animatable(1f) }
    val scope = rememberCoroutineScope()
    Column(barSpotModifier().fillMaxWidth()
        .dropShadow(RoundedCornerShape(0.dp), Shadow(24.dp, G.shade.copy(alpha = .10f), offset = DpOffset(0.dp, (-6).dp)))
        .glassBlur(haze, barFill(), 20.dp).background(barFill())
        .drawBehind { drawRect(G.ink.copy(alpha = .08f), Offset.Zero, Size(size.width, 1.dp.toPx())) }
        .navigationBarsPadding().padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (onUndo != null) BarIcon("undo", tr("ux.undo"), canUndo, onUndo, if (undoCoach != null) Modifier.coachSpot(undoCoach) else Modifier)
            if (onRedo != null && canRedo) BarIcon("redo", tr("common.redo"), true, onRedo)
            seg?.invoke()
            val shape = RoundedCornerShape(18.dp)
            val bg = mainColor ?: G.cobalt
            Row(Modifier.weight(1f).heightIn(min = 54.dp).let { if (coach != null) it.coachSpot(coach) else it }
                .graphicsLayer { scaleX = pulse.value; scaleY = pulse.value }
                .dropShadow(shape, Shadow(18.dp, if (mainEnabled) bg.copy(alpha = .3f) else Color.Transparent, offset = DpOffset(0.dp, 8.dp)))
                .clip(shape).background(bg).graphicsLayer { alpha = if (mainEnabled) 1f else .42f }
                .pressable({
                    if (mainEnabled) {
                        scope.launch { pulse.snapTo(.96f); pulse.animateTo(1f, tween(220)) }
                        onMain()
                    }
                }, .98f).padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                if (mainIcon != null) UxIcon(mainIcon, Color.White, 20.dp, 2.2f)
                Text(main, style = ui(16f, 800, Color.White, 1.15f).copy(textAlign = TextAlign.Center), maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
        below?.invoke()
    }
}

/** The designers' 2D/3D switch, in the bottom bar. */
@Composable
fun Seg2D3D(d3: Boolean, onPick: (Boolean) -> Unit) {
    val app = LocalApp.current
    Row(Modifier.height(52.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f)).padding(4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        listOf(false to "2D", true to "3D").forEach { (v, l) ->
            val on = v == d3
            Box(Modifier.width(48.dp).height(44.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.solid else Color.Transparent)
                .clickable(role = Role.Tab) { if (!on) { app.haptic(Hap.TICK); onPick(v) } }, contentAlignment = Alignment.Center) {
                Text(l, style = ui(15f, if (on) 800 else 600, if (on) G.ink else G.ink2))
            }
        }
    }
}

/** The order's progress (§2): ✓ done, the current step blue, "–" for no room; each step opens its place. [compact]: the designer's. */
@Composable
fun ProgressRow(p: Project, compact: Boolean = false) {
    val app = LocalApp.current
    val steps = fSteps(app, p)
    val d: Dp = if (compact) 20.dp else 26.dp
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        steps.forEachIndexed { i, s ->
            val (bg, fg) = when (s.state) {
                StepState.DONE -> G.green to Color.White
                StepState.CUR -> G.cobalt to Color.White
                StepState.SKIP -> G.ink.copy(alpha = .08f) to G.ink3
                StepState.TODO -> G.ink.copy(alpha = .08f) to G.ink2
            }
            Column(Modifier.weight(1f).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.openStep(p, s.key) }.padding(vertical = if (compact) 2.dp else 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (compact) 2.dp else 4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f).height(2.dp).background(if (i == 0) Color.Transparent else if (s.state == StepState.DONE || s.state == StepState.CUR) G.cobalt.copy(alpha = .35f) else G.ink.copy(alpha = .1f)))
                    Box(Modifier.size(d).clip(CircleShape).background(bg)
                        .let { if (s.state == StepState.CUR) it.border(3.dp, G.cobalt.copy(alpha = .25f), CircleShape) else it }, contentAlignment = Alignment.Center) {
                        when (s.state) {
                            StepState.DONE -> MIcon("check", fg, if (compact) 11.dp else 14.dp, 3f)
                            StepState.SKIP -> Text("–", style = ui(if (compact) 11f else 13f, 800, fg))
                            else -> Text("${i + 1}", style = ui(if (compact) 10.5f else 12.5f, 800, fg))
                        }
                    }
                    Box(Modifier.weight(1f).height(2.dp).background(if (i == steps.lastIndex) Color.Transparent else if (s.state == StepState.DONE) G.cobalt.copy(alpha = .35f) else G.ink.copy(alpha = .1f)))
                }
                Text(s.label, style = ui(if (compact) 10.5f else 11.5f, if (s.state == StepState.CUR) 800 else 600,
                    if (s.state == StepState.CUR) G.cobalt2 else if (s.state == StepState.DONE) G.ink else G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center)
            }
        }
    }
}

/** The order cards' small 5-segment line and "Keyingi: <step>" (§2). */
@Composable
fun MiniProgress(p: Project, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val steps = fSteps(app, p)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            steps.forEach { s ->
                Box(Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(3.dp)).background(when (s.state) {
                    StepState.DONE, StepState.SKIP -> G.green
                    StepState.CUR -> G.cobalt
                    StepState.TODO -> G.ink.copy(alpha = .12f)
                }))
            }
        }
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            // simple mode: the grey "≈ … so‘m (taxminiy)"; Advanced: the exact price (§4)
            val price = app.priceWords(p, short = app.settings.advanced)
            Text(price ?: "", style = ui(12.5f, if (app.settings.advanced) 700 else 600, if (app.settings.advanced) G.ink else G.ink3, 1.3f), maxLines = 2,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            val next = app.nextStepName(p)
            Text(if (next != null) tr("ux.nextV", "s" to next) else tr("ux.sentDone"), style = ui(12.5f, 700, if (next != null) G.cobalt2 else G.green), maxLines = 1)
        }
    }
}

/** The order header's price line (§4): simple mode grey "≈ … (taxminiy)", Advanced the exact client price. */
@Composable
fun PriceLine(p: Project) {
    val app = LocalApp.current
    val w = app.priceWords(p)
    Text(w ?: tr("ux.priceLater"), style = ui(13.5f, if (w != null && app.settings.advanced) 700 else 600, if (w == null) G.ink3 else if (app.settings.advanced) G.ink else G.ink3),
        maxLines = 2)
}

/** A two-way switch (Mebel | Ma’lumot). */
@Composable
fun UxSeg(items: List<Pair<String, String>>, cur: String, onPick: (String) -> Unit) {
    val app = LocalApp.current
    Row(Modifier.fillMaxWidth().height(46.dp).clip(RoundedCornerShape(23.dp)).background(G.ink.copy(alpha = .06f)).padding(4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        items.forEach { (k, l) ->
            val on = k == cur
            Box(Modifier.weight(1f).height(38.dp).clip(RoundedCornerShape(19.dp)).background(if (on) G.solid else Color.Transparent)
                .clickable(role = Role.Tab) { if (!on) { app.haptic(Hap.TICK); onPick(k) } }, contentAlignment = Alignment.Center) {
                Text(l, style = ui(14.5f, if (on) 800 else 600, if (on) G.ink else G.ink2), maxLines = 1)
            }
        }
    }
}
