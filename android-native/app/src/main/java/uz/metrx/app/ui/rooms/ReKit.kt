package uz.metrx.app.ui.rooms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import kotlin.math.roundToInt
import uz.metrx.app.ui.App
import uz.metrx.app.ui.icons.PathIcon

/** A chip's or a secondary button's fill on the white cards (the mockup's glass2 on the sheet). */
val chipBg: Color get() = G.ink.copy(alpha = .06f)

/**
 * A distance or size bubble centred on [x], [y] (px): blue, green while a magnet holds it; [small] in the floating
 * card's front view. Kept inside its box.
 */
@Composable
fun BoxScope.ReBubble(text: String, x: Float, y: Float, live: Boolean = false, small: Boolean = false, onClick: (() -> Unit)? = null) {
    val d = LocalDensity.current
    val h = if (small) 24 else 30
    val pad = with(d) { 4.dp.roundToPx() }
    Row(Modifier.layout { m, cs ->
        val pl = m.measure(cs.copy(minWidth = 0, minHeight = 0))
        val left = (x - pl.width / 2f).roundToInt().coerceIn(pad, kotlin.math.max(pad, cs.maxWidth - pl.width - pad))
        val top = (y - pl.height / 2f).roundToInt().coerceIn(pad, kotlin.math.max(pad, cs.maxHeight - pl.height - pad))
        layout(pl.width, pl.height) { pl.place(left, top) }
    }.height(h.dp).clip(RoundedCornerShape((h / 2).dp)).background(if (live) G.green else G.cobalt)
        .let { if (onClick != null) it.clickable(role = Role.Button, onClick = onClick) else it }
        .padding(horizontal = if (small) 8.dp else 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = num(if (small) 11.5f else 12.5f, 800, Color.White), maxLines = 1)
    }
}

/*
 * Small shared pieces of the room editor v2 (mockup design/room-editor/mockup.html): its icons, each kind's colour and
 * name, and numbers written "3 400" as everywhere in the app.
 */

/** A mockup icon by name (RE_ICONS), stroked in [color]. */
@Composable
fun ReIcon(name: String, color: Color, size: Dp = 22.dp, stroke: Float = 2f, modifier: Modifier = Modifier) {
    PathIcon(RE_ICONS[name] ?: KIND_ICONS[name] ?: return, color, size, stroke, modifier)
}

/** A kind's icon in its own colour. */
@Composable
fun KindIcon(kind: String, size: Dp = 24.dp, color: Color? = null) {
    PathIcon(KIND_ICONS[kind] ?: return, color ?: kindColor(kind), size, 2f)
}

/** A kind's icon, white on a rounded square of its colour (the floating card, the list). */
@Composable
fun KindBadge(kind: String, size: Dp = 36.dp) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * .3f)).background(kindColor(kind)), contentAlignment = Alignment.Center) {
        PathIcon(KIND_ICONS[kind] ?: return@Box, Color.White, size * .56f, 2f)
    }
}

fun kindColor(kind: String) = Color(KIND_COLORS[kind] ?: 0xFF64748BL)

/**
 * A length as the room editor, the room flow, the openings and the inner walls show it: in the role's unit
 * ([uz.metrx.app.geo.RoomUnit], 1.0.2): "3 400" mm with thin groups (the mockup's fmt), "3,40" m, "340" cm.
 */
fun mm(v: Int): String = uz.metrx.app.geo.RoomUnit.text(v)

/** The room unit's word (mm, sm, m). */
fun App.lu(): String = t(uz.metrx.app.geo.unitKey(uz.metrx.app.geo.RoomUnit.unit))

/** The unit the rooms of order [pid] are shown and typed in: a furniture maker's furniture unit (mm), else Profile's (m or cm). */
fun App.roomUnit(pid: String?, trade: String? = null): uz.metrx.app.geo.LenUnit =
    if (trade == "furniture" || pid?.let { store.get(it) }?.isFurniture == true || (pid == null && trade == null && settings.furniture)) settings.furnUnit else settings.unit

/** Makes the room screens of order [pid] show and take lengths in its unit (called as they compose). */
fun App.useRoomUnit(pid: String?, trade: String? = null) = uz.metrx.app.geo.RoomUnit.set(roomUnit(pid, trade), settings.lang == uz.metrx.app.core.Lang.EN)

/** A kind's name ("Eshik", "Rozetka"). */
fun App.kindName(kind: String) = t("re.k.$kind")

/** The same in the middle of a sentence ("eshik", "rozetka"): lower-case in every language. */
fun App.kindLow(kind: String) = kindName(kind).replaceFirstChar { it.lowercase() }

/** A style's name ("Bir tabaqali") and its note ("stol ustida"), or null. */
fun App.styleName(kind: String, id: String) = t("st.$kind.$id")
fun App.styleNote(kind: String, id: String): String? = if (uz.metrx.app.geo.styleOf(kind, id).note) t("st.$kind.$id.d") else null
