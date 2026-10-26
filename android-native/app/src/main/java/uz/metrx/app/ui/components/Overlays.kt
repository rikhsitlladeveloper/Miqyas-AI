package uz.metrx.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/**
 * A glass bottom sheet (prototype .sheet in the glass look): white .84 over a 30 dp blur, a grab handle,
 * a title row with a close button, the body, and an optional footer above a hairline.
 */
@Composable
fun GlassSheet(title: String, onClose: () -> Unit, footer: (@Composable ColumnScope.() -> Unit)? = null, back: (() -> Unit)? = null, body: @Composable ColumnScope.() -> Unit) {
    val haze = LocalHaze.current
    // slides up from the bottom while the scrim fades in (prototype .sheet.anim)
    val enter = remember { androidx.compose.animation.core.Animatable(1f) }
    LaunchedEffect(Unit) { enter.animateTo(0f, tween(280, easing = CubicBezierEasing(.3f, .7f, .2f, 1f))) }
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().graphicsLayer { alpha = 1f - enter.value }.background(G.scrim).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose))
        val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
        // the sheet stays below the status bar and above the keyboard; a long body scrolls inside it
        Box(Modifier.fillMaxSize().statusBarsPadding().padding(top = 24.dp).imePadding(), contentAlignment = Alignment.BottomCenter) {
        Column(
            Modifier.fillMaxWidth()
                .graphicsLayer { translationY = size.height * enter.value }
                .dropShadow(shape, Shadow(40.dp, G.shade.copy(alpha = .16f), offset = DpOffset(0.dp, (-12).dp)))
                .clip(shape).glassBlur(haze, G.sheet(.92f), 30.dp).topHighlight(1f)
                .border(1.dp, G.rim, shape)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                .navigationBarsPadding()
        ) {
            Box(Modifier.padding(top = 7.dp).size(36.dp, 4.dp).clip(RoundedCornerShape(2.dp)).background(G.rim).align(Alignment.CenterHorizontally))
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(start = if (back != null) 6.dp else 16.dp, end = 6.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                if (back != null) Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = back), contentAlignment = Alignment.Center) { MIcon("back", G.ink, 22.dp, 2f) }
                Text(title, style = ui(17f, 600, lineHeight = 1.25f), modifier = Modifier.weight(1f))
                Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClose), contentAlignment = Alignment.Center) { MIcon("x", G.ink2, 22.dp, 2f) }
            }
            androidx.compose.runtime.CompositionLocalProvider(uz.metrx.app.ui.theme.LocalOnSheet provides true) {
            Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = body)
            if (footer != null) {
                Box(Modifier.fillMaxWidth().height(1.dp).background(G.ink.copy(alpha = .08f)))
                Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = footer)
            }
            }
        }
        }
    }
}

/** Primary and secondary buttons of the glass screens. */
@Composable
fun GlassButton(label: String, onClick: () -> Unit, primary: Boolean = true, icon: String? = null, enabled: Boolean = true, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier.fillMaxWidth().heightIn(min = 52.dp)
            .dropShadow(shape, Shadow(22.dp, if (primary && enabled) G.cobalt.copy(alpha = .3f) else Color.Transparent, offset = DpOffset(0.dp, 10.dp)))
            .clip(shape).background(if (primary) G.cobalt else G.idle(.6f))
            .let { if (primary) it else it.border(1.dp, G.rim, shape) }
            .pressable({ if (enabled) onClick() }, .98f).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) MIcon(icon, if (primary) Color.White else G.ink, 18.dp, 2.2f)
        Text(label, style = ui(16f, 700, if (primary) Color.White else G.ink))
    }
}

enum class ToastKind { OK, INFO, ERROR }
data class ToastMsg(val text: String, val kind: ToastKind = ToastKind.OK, val action: String? = null, val onAction: (() -> Unit)? = null, val id: Long = System.nanoTime())

private val TOAST_IN = CubicBezierEasing(.2f, .9f, .3f, 1.15f)

/**
 * The toast of the prototype's last UX pass: one dark card at the top, its colour and icon say what happened,
 * a thin bar shows the time left; tap the cross to close.
 */
@Composable
fun ToastHost(msg: ToastMsg?, bottomPx: Int? = null, atTop: Boolean = false, onGone: () -> Unit) {
    var shown by remember { mutableStateOf<ToastMsg?>(null) }
    var visible by remember { mutableStateOf(false) }
    // the toast whose action already ran: a second tap during the exit animation must not run Undo again
    var acted by remember { mutableStateOf<Long?>(null) }
    LaunchedEffect(msg?.id) {
        if (msg == null) return@LaunchedEffect
        shown = msg; visible = true
        // a toast with Undo stays long enough to reach it (about 6 s)
        delay(if (msg.action != null) 6500 else if (msg.kind == ToastKind.ERROR) 5200 else 3400)
        visible = false; delay(260); onGone()
    }
    // UX upgrades §3: at the bottom, just above the page's bottom bar, so it never covers Back and its Undo is in thumb
    // reach; at the top only while a sheet is open (the sheet's buttons are at the bottom)
    val density = androidx.compose.ui.platform.LocalDensity.current
    val lift = with(density) { (bottomPx ?: 0).toDp() }
    Box((if (atTop) Modifier.fillMaxSize().statusBarsPadding().padding(start = 10.dp, end = 10.dp, top = 8.dp)
        else Modifier.fillMaxSize().let { if (bottomPx == null) it.navigationBarsPadding().padding(bottom = 16.dp) else it.padding(bottom = lift + 8.dp) }.padding(horizontal = 10.dp)),
        contentAlignment = if (atTop) Alignment.TopCenter else Alignment.BottomCenter) {
        AnimatedVisibility(visible, enter = slideInVertically(tween(340, easing = TOAST_IN)) { if (atTop) -it else it } + fadeIn(tween(200)),
            exit = slideOutVertically(tween(220)) { if (atTop) -it - 40 else it + 40 } + fadeOut(tween(200))) {
            val m = shown ?: return@AnimatedVisibility
            val (tc, icon) = when (m.kind) {
                ToastKind.OK -> Color(0xFF5BE49B) to "check"
                ToastKind.INFO -> Color(0xFF9DB1FF) to "info"
                ToastKind.ERROR -> Color(0xFFFF7A7A) to "alert"
            }
            val shape = RoundedCornerShape(18.dp)
            Row(
                Modifier.fillMaxWidth().heightIn(min = 58.dp)
                    .dropShadow(shape, Shadow(32.dp, Color(0x52000000), offset = DpOffset(0.dp, 12.dp)))
                    .clip(shape).background(Color(0xFF0F1626)).padding(start = 12.dp, end = 8.dp, top = 9.dp, bottom = 11.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(Modifier.size(32.dp).clip(CircleShape).background(tc.copy(alpha = .2f)), contentAlignment = Alignment.Center) { MIcon(icon, tc, 18.dp, 2.4f) }
                val action: (@Composable () -> Unit)? = m.action?.let { label -> {
                    Row(
                        Modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(13.dp)).background(Color.White.copy(alpha = .12f))
                            .clickable(role = Role.Button) { if (acted != m.id) { acted = m.id; m.onAction?.invoke() }; visible = false }.padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) { MIcon("undo", Color.White, 16.dp, 2.2f); Text(label, style = ui(14f, 700, Color.White), maxLines = 1) }
                } }
                // a long message keeps the full width and puts its button underneath, instead of a narrow column beside it
                val below = action != null && m.text.length + m.action!!.length > 24
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(m.text, style = ui(14.5f, 600, Color.White, 1.35f))
                    if (below) action!!()
                }
                if (action != null && !below) action()
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { visible = false }, contentAlignment = Alignment.Center) {
                    MIcon("x", Color.White.copy(alpha = .62f), 18.dp, 2f)
                }
            }
        }
    }
}
