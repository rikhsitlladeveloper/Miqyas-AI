package uz.metrx.app.ui.glass

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.HazeTint
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import uz.metrx.app.ui.theme.G

/** The page content that glass layers (tab bar, sheets, header buttons) blur. */
val LocalHaze = staticCompositionLocalOf<HazeState?> { null }

/**
 * The aurora light behind every glass screen: four soft glows on #EEF1F8, sized in dp like the prototype's CSS px
 * (radial-gradient(330px at 6% 4%, rgba(91,123,255,.62) → transparent at 70%), and so on).
 */
fun Modifier.aurora(): Modifier = drawBehind { drawAurora(size, Offset.Zero) }

/** The aurora of a [full]-sized screen, drawn with the screen's top left at [origin] (used to paint over corners). */
fun androidx.compose.ui.graphics.drawscope.DrawScope.drawAurora(full: androidx.compose.ui.geometry.Size, origin: Offset) {
    drawRect(G.paper)
    fun glow(xPct: Float, yPct: Float, r: Dp, c: Color, a: Float) {
        val rad = r.toPx()
        drawRect(Brush.radialGradient(0f to c.copy(alpha = a), .7f to c.copy(alpha = 0f), center = Offset(origin.x + full.width * xPct, origin.y + full.height * yPct), radius = rad))
    }
    // at night the same four glows, dimmed, as light seen through smoked glass
    val k = if (uz.metrx.app.ui.theme.Theme.dark) .45f else 1f
    glow(.06f, .04f, 330.dp, G.auroraBlue, .62f * k)
    glow(1f, .28f, 300.dp, G.auroraViolet, .48f * k)
    glow(.04f, .70f, 340.dp, G.auroraCyan, .40f * k)
    glow(1f, 1f, 300.dp, G.auroraPeach, .50f * k * .6f)
}

@Composable
fun AuroraBox(haze: HazeState?, modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.fillMaxSize().aurora().let { if (haze != null) it.hazeSource(haze) else it }, content = content)
}

/**
 * A frosted card that sits on the soft background (no real blur needed): see-through white, a white rim,
 * a bright inner top edge and a soft blue-grey shadow (prototype .gl-big / .gl-sm / .gl-pc).
 */
fun Modifier.glassCard(
    shape: Shape,
    fill: Color = G.fill,
    shadowRadius: Dp = 28.dp,
    shadowY: Dp = 12.dp,
    shadowAlpha: Float = .12f
): Modifier = this
    .dropShadow(shape, Shadow(radius = shadowRadius, color = G.shade.copy(alpha = shadowAlpha), offset = DpOffset(0.dp, shadowY)))
    .clip(shape)
    .background(fill)
    .topHighlight()
    .border(1.dp, G.rim, shape)

/** inset 0 1.5px 0 rgba(255,255,255,.95): a bright line along the inside of the top edge. */
fun Modifier.topHighlight(alpha: Float = .95f, width: Dp = 1.5.dp): Modifier = drawWithContent {
    drawContent()
    drawRect(G.hi(alpha), size = size.copy(height = width.toPx()))
}

/**
 * Real glass for layers that content moves behind: blurs the page under it on Android 12+ (Haze). Older phones cannot
 * blur: there the layer is a solid pale cool grey in the light look (not white), so the white glass fields, chips and
 * buttons on it still show; on a plain white sheet they vanished (the founder's Mi 6X, Android 8.1).
 */
fun Modifier.glassBlur(haze: HazeState?, tint: Color, blur: Dp = 26.dp): Modifier {
    val a = minOf(1f, tint.alpha + .35f)
    val white = tint.red > .97f && tint.green > .97f && tint.blue > .97f
    val fallback = if (white) Color(0xFFEDF0F6).copy(alpha = a) else tint.copy(alpha = a)
    return if (haze == null) background(tint) else hazeEffect(haze) {
        blurRadius = blur
        tints = listOf(HazeTint(tint))
        fallbackTint = HazeTint(fallback)
        noiseFactor = 0f
    }
}
