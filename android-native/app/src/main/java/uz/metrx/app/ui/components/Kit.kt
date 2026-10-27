package uz.metrx.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Laser
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalSettings
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

private val M_PATH by lazy { PathParser().parsePathString("M15 47V19l17 19 17-19v28").toPath() }
private val TICKS by lazy { PathParser().parsePathString("M11.5 28h3M11.5 34h3M11.5 40h3M49.5 28h3M49.5 34h3M49.5 40h3").toPath() }

/** The METRX mark drawn in a 64 × 64 box: a white M with the three corner dots and the ruler ticks cut in [tile]. */
fun DrawScope.drawLogoMark(tile: Color, boxPx: Float, origin: Offset = Offset.Zero) {
    val k = boxPx / 64f
    withTransform({ translate(origin.x, origin.y); scale(k, k, pivot = Offset.Zero) }) {
        drawPath(M_PATH, Color.White, style = Stroke(7f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        listOf(Offset(15f, 19f), Offset(32f, 38f), Offset(49f, 19f)).forEach { drawCircle(tile, 1.9f, it) }
        drawPath(TICKS, tile, style = Stroke(1.4f))
    }
}

/** The logo tile: 38 dp, corner 11 dp, #3550E0 on glass screens (prototype .wordmark::before). */
@Composable
fun LogoTile(size: Dp = 38.dp, corner: Dp = 11.dp, color: Color = G.cobalt, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size).clip(RoundedCornerShape(corner)).background(color)) { drawLogoMark(color, this.size.width) }
}

/** Logo and the spaced METRX name (prototype .wordmark in the glass header). */
@Composable
fun Wordmark(modifier: Modifier = Modifier) {
    Row(modifier.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        LogoTile()
        Text("METRX", style = ui(19f, 700, spacing = .32f).copy(fontFamily = uz.metrx.app.ui.theme.Jakarta))
    }
}

/** A press effect like the prototype's :active { transform: scale(.985) }. */
@Composable
fun Modifier.pressable(onClick: () -> Unit, pressedScale: Float = .985f, role: Role = Role.Button, label: String? = null): Modifier {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) pressedScale else 1f, label = "press")
    return this
        .scale(s)
        .let { if (label != null) it.semantics { contentDescription = label } else it }
        .clickable(interactionSource = src, indication = null, role = role, onClick = onClick)
}

private const val BT_RUNE = "M6.5 6.5L17.5 17.5L12 23L12 1L17.5 6.5L6.5 17.5"

/**
 * The round laser button at the top right (prototype .gl-bt): grey with a grey dot when not connected,
 * green with a green dot when connected. The colour is never the only signal: the label says the state.
 */
@Composable
fun LaserButton(onClick: () -> Unit) {
    val settings = LocalSettings.current
    val on = settings.laser == Laser.CONNECTED
    val c = if (on) G.green else G.greyIcon
    val haze = LocalHaze.current
    Box(
        Modifier
            .size(48.dp)
            .dropShadow(CircleShape, Shadow(24.dp, G.shade.copy(alpha = .14f), offset = DpOffset(0.dp, 8.dp)))
            .clip(CircleShape)
            .glassBlur(haze, G.sheet(.42f), 22.dp)
            .topHighlight(.95f, 1.dp)
            .border(1.dp, G.rim, CircleShape)
            .pressable(onClick, .95f, label = tr(if (on) "gl.btOn" else "gl.btOff")),
        contentAlignment = Alignment.Center
    ) {
        PathIcon(BT_RUNE, c, 22.dp, 2.2f)
        Box(Modifier.align(Alignment.TopEnd).offset((-9).dp, 9.dp).size(9.dp).clip(CircleShape).background(G.solid).padding(2.dp).clip(CircleShape).background(c))
    }
}

/**
 * The laser's chip with its state in words, "Lazer ulanmagan" / "Ulanmoqda…" / "Lazer ulangan" (UX upgrades mockup:
 * the furniture maker's Home, Buyurtmalar and Profil). A tap opens the laser's page, as the round button does.
 */
@Composable
fun LaserChip(onClick: () -> Unit) {
    val settings = LocalSettings.current
    val on = settings.laser == Laser.CONNECTED
    val busy = settings.laser == Laser.SEARCHING || settings.laser == Laser.FOUND
    val c = if (on) G.green else G.ink2
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(22.dp)
    Row(
        Modifier.heightIn(min = 44.dp).widthIn(max = 220.dp)
            .dropShadow(shape, Shadow(20.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 6.dp)))
            .clip(shape).glassBlur(haze, G.sheet(.6f), 22.dp).topHighlight(.95f, 1.dp).border(1.dp, G.rim, shape)
            .pressable(onClick, .96f).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        PathIcon(BT_RUNE, if (on) G.green else G.greyIcon, 17.dp, 2.2f)
        Text(tr(if (on) "gl.btOn" else if (busy) "lz.connecting" else "gl.btOff"), style = ui(12.5f, 700, c, 1.15f), maxLines = 2)
    }
}

/** The glass header: logo and name on the left, the laser button (or with [labeled] its chip in words) on the right, 64 dp tall. */
@Composable
fun GlassHeader(onLaser: () -> Unit, modifier: Modifier = Modifier, labeled: Boolean = false, left: (@Composable () -> Unit)? = null) {
    Row(modifier.padding(start = 8.dp, end = 12.dp).let { it }.then(Modifier.padding(vertical = 8.dp)), verticalAlignment = Alignment.CenterVertically) {
        if (left != null) left() else Wordmark()
        Spacer(Modifier.weight(1f))
        if (labeled) LaserChip(onLaser) else LaserButton(onLaser)
    }
}

@Composable
fun HSpace(w: Dp) = Spacer(Modifier.width(w))
