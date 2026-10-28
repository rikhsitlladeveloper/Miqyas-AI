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
import uz.metrx.app.ui.App
import uz.metrx.app.ui.icons.PathIcon

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

/** "3 400": mm with thin groups, as the mockup's fmt. */
fun mm(v: Int): String = fmtMm(kotlin.math.abs(v).toDouble())

/** A kind's name ("Eshik", "Rozetka"). */
fun App.kindName(kind: String) = t("re.k.$kind")

/** The same in the middle of a sentence ("eshik", "rozetka"): lower-case in every language. */
fun App.kindLow(kind: String) = kindName(kind).replaceFirstChar { it.lowercase() }

/** A style's name ("Bir tabaqali") and its note ("stol ustida"), or null. */
fun App.styleName(kind: String, id: String) = t("st.$kind.$id")
fun App.styleNote(kind: String, id: String): String? = if (uz.metrx.app.geo.styleOf(kind, id).note) t("st.$kind.$id.d") else null
