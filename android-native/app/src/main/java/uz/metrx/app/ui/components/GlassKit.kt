package uz.metrx.app.ui.components

import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/* Pieces of the glass screens inside a project (values read from the running prototype's computed styles). */

/** Round glass icon button, 44 dp (prototype .bar .ib). */
@Composable
fun GlassIconButton(icon: String, label: String, onClick: () -> Unit, modifier: Modifier = Modifier, size: Dp = 44.dp, iconSize: Dp = 22.dp, tint: Color = G.ink) {
    Box(
        modifier.size(size)
            .dropShadow(CircleShape, Shadow(18.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, 6.dp)))
            .clip(CircleShape).background(G.glass(.42f)).topHighlight(.95f, 1.dp)
            .border(1.dp, G.rim, CircleShape)
            .pressable(onClick, .95f, label = label),
        contentAlignment = Alignment.Center
    ) { MIcon(icon, tint, iconSize, 2f) }
}

/** The back pill with the parent's name (prototype button.back in the glass header). */
@Composable
fun BackPill(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(22.dp)
    Row(
        modifier.height(44.dp)
            .dropShadow(shape, Shadow(18.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, 6.dp)))
            .clip(shape).background(G.glass(.45f)).topHighlight(1f, 1.dp).border(1.dp, G.rim, shape)
            .pressable(onClick, .97f).padding(start = 6.dp, end = 16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        MIcon("back", G.ink, 22.dp, 2.2f)
        Text(text, style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** A plain back button: round glass icon, then the parent's name (prototype .page.space button.back). */
@Composable
fun BackLink(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        GlassIconButton("back", tr("nt.back"), onClick)
        Text(text, style = ui(15f, 700, G.slate), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** A page header row, 64 dp, 8 dp left and 12 dp right like the prototype's .bar. */
@Composable
fun PageBar(modifier: Modifier = Modifier, frosted: Boolean = false, content: @Composable RowScope.() -> Unit) {
    Row(
        modifier.fillMaxWidth()
            .let { if (frosted) it.background(G.sheet(.55f)).drawBehind { drawRect(G.rim, Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) } else it }
            .heightIn(min = 64.dp).padding(start = 8.dp, end = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp), content = content
    )
}

/** Two-line title: a small coloured step above the title (prototype .ttl small.ey + b). */
@Composable
fun RowScope.BarTitle(title: String, eyebrow: String? = null, sub: String? = null) {
    Column(Modifier.weight(1f).padding(start = 4.dp)) {
        if (eyebrow != null) Text(eyebrow, style = ui(12.5f, 600, G.cobalt), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(title, style = ui(17f, 700, lineHeight = 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (sub != null) Text(sub, style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The floating frosted footer that holds a page's main button (prototype .footer in the glass look). */
@Composable
fun FloatingFooter(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(30.dp)
    Column(
        modifier.fillMaxWidth().navigationBarsPadding().padding(start = 12.dp, end = 12.dp, bottom = 12.dp)
            .dropShadow(shape, Shadow(30.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, (-10).dp)))
            .clip(shape).glassBlur(haze, G.sheet(.55f), 28.dp).topHighlight(.95f)
            .border(1.dp, G.rim, shape).padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp), content = content
    )
}

enum class Btn { PRIMARY, SECONDARY, DANGER }

/** Buttons of the glass screens: 54 dp, corner 18, primary blue with a soft blue shadow, secondary a grey wash. */
@Composable
fun GBtn(label: String, onClick: () -> Unit, kind: Btn = Btn.PRIMARY, icon: String? = null, enabled: Boolean = true,
         modifier: Modifier = Modifier, height: Dp = 54.dp, corner: Dp = 18.dp, fontSize: Float = 16f, fill: Boolean = true, maxLines: Int = 1) {
    val shape = RoundedCornerShape(corner)
    val bg = when (kind) { Btn.PRIMARY -> G.cobalt; Btn.SECONDARY -> G.ink.copy(alpha = .06f); Btn.DANGER -> Color(0xFFB42318) }
    val fg = if (kind == Btn.SECONDARY) G.ink else Color.White
    Row(
        modifier.let { if (fill) it.fillMaxWidth() else it }.heightIn(min = height)
            // the shadow and the fade stay in the chain whatever [enabled] is: switching them in and out of a button already
            // on screen made it lose its fill (the "Davom etish" / "Buyurtma yaratish" buttons turned pale when enabled)
            .dropShadow(shape, Shadow(18.dp, if (kind == Btn.PRIMARY && enabled) Color(0x38374FDD) else Color.Transparent, offset = DpOffset(0.dp, 8.dp)))
            .clip(shape).background(bg).graphicsLayer { alpha = if (enabled) 1f else .42f }
            .pressable({ if (enabled) onClick() }, .98f).padding(horizontal = if (height < 50.dp) 12.dp else 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) MIcon(icon, fg, 18.dp, 2.2f)
        Text(label, style = ui(fontSize, 700, fg, if (maxLines > 1) 1.15f else null).copy(textAlign = androidx.compose.ui.text.style.TextAlign.Center), maxLines = maxLines, overflow = TextOverflow.Ellipsis)
    }
}

/** Shows "90 123 45 67" while the field keeps only digits. */
object PhoneGroups : VisualTransformation {
    private val breaks = intArrayOf(2, 5, 7)
    override fun filter(text: AnnotatedString): TransformedText {
        val d = text.text
        val sb = StringBuilder()
        d.forEachIndexed { i, c -> if (i in breaks) sb.append(' '); sb.append(c) }
        return TransformedText(AnnotatedString(sb.toString()), object : OffsetMapping {
            override fun originalToTransformed(offset: Int) = offset + breaks.count { it < offset }
            override fun transformedToOriginal(offset: Int): Int {
                var o = offset; var spaces = 0
                for (b in breaks) if (b + spaces < offset && b < d.length) { o--; spaces++ }
                return o.coerceIn(0, d.length)
            }
        })
    }
}

/** Sums typed as digits show in groups of three ("28 921 620"), as everywhere else in the app; the value stays digits. */
object DigitGroups : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val d = text.text
        if (d.length < 4 || !d.all { it.isDigit() }) return TransformedText(text, OffsetMapping.Identity)
        val first = d.length % 3
        val sb = StringBuilder()
        d.forEachIndexed { i, c -> if (i > 0 && (i - first) % 3 == 0) sb.append(' '); sb.append(c) }
        val out = sb.toString()
        // where each digit lands in the grouped text
        val pos = IntArray(d.length + 1); var j = 0
        for (i in d.indices) { if (i > 0 && (i - first) % 3 == 0) j++; pos[i] = j; j++ }
        pos[d.length] = out.length
        return TransformedText(AnnotatedString(out), object : OffsetMapping {
            override fun originalToTransformed(offset: Int) = pos[offset.coerceIn(0, d.length)]
            override fun transformedToOriginal(offset: Int): Int { var i = 0; while (i < d.length && pos[i] < offset) i++; return i }
        })
    }
}

fun phoneDigits(v: String): String {
    var d = v.filter { it.isDigit() }
    if (d.length > 9 && d.startsWith("998")) d = d.substring(3)
    return d.take(9)
}

/**
 * A labelled glass field (prototype .fld / .box): white .6, a white rim, corner 16, 56 dp; focused it gets a 2 dp blue
 * border and a pale blue halo; with an error a red border and the message underneath.
 */
@Composable
fun GField(
    label: String?, value: String, onValue: (String) -> Unit, placeholder: String = "",
    optional: Boolean = false, phone: Boolean = false, error: String? = null, showError: Boolean = false,
    imeAction: ImeAction = ImeAction.Next, onIme: () -> Unit = {}, onBlur: () -> Unit = {},
    focusRequester: FocusRequester = remember { FocusRequester() }, minLines: Int = 1, labelRight: String? = null,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Sentences, done: Boolean = false,
    modifier: Modifier = Modifier, number: Boolean = false, money: Boolean = false, decimal: Boolean = false
) {
    var focused by remember { mutableStateOf(false) }
    val bad = showError && error != null
    val shape = RoundedCornerShape(16.dp)
    // on focus the whole field (label to error line) scrolls into view, not just the cursor, so a button
    // above the keyboard never covers half of it
    val whole = remember { androidx.compose.foundation.relocation.BringIntoViewRequester() }
    LaunchedEffect(focused) { if (focused) { kotlinx.coroutines.delay(250); whole.bringIntoView() } }
    Column(modifier.fillMaxWidth().bringIntoViewRequester(whole), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (label != null) Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, style = ui(15f, 700), modifier = Modifier.weight(1f))
            if (optional) Text(tr("common.optional").replaceFirstChar { it.uppercase() }, style = ui(13f, 500, G.ink3))
            if (labelRight != null) Text(labelRight, style = ui(13f, 500, G.ink3))
        }
        val edge = when { bad -> G.err; focused -> G.cobalt; else -> G.rim }
        Row(
            Modifier.fillMaxWidth()
                .drawBehind {
                    if (focused) {
                        val o = 4.dp.toPx()
                        drawRoundRect((if (bad) G.err else G.cobalt).copy(alpha = .12f), Offset(-o / 2, -o / 2), Size(size.width + o, size.height + o), CornerRadius(16.dp.toPx() + o / 2), style = Stroke(o))
                    }
                }
                .clip(shape).background(G.glass(.6f)).border(if (focused || bad) 2.dp else 1.dp, edge, shape)
                .heightIn(min = if (minLines > 1) 117.dp else 56.dp).padding(horizontal = if (focused) 17.dp else 18.dp),
            verticalAlignment = if (minLines > 1) Alignment.Top else Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (phone) Text("+998", style = ui(16f, 500, G.ink3))
            val style = ui(16f, 400, if (done) G.ink3 else G.ink, if (minLines > 1) 1.45f else null).copy(textDecoration = if (done) TextDecoration.LineThrough else null)
            Box(Modifier.weight(1f).padding(vertical = if (minLines > 1) 12.dp else 10.dp)) {
                if (value.isEmpty()) Text(placeholder, style = style.copy(color = G.greyIcon, textDecoration = null))
                BasicTextField(
                    value = value, onValueChange = { onValue(if (phone) phoneDigits(it) else it) },
                    singleLine = minLines == 1, minLines = minLines, textStyle = style, cursorBrush = SolidColor(G.cobalt),
                    visualTransformation = if (phone) PhoneGroups else if (money) DigitGroups else VisualTransformation.None,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = if (phone) KeyboardType.Phone else if (decimal) KeyboardType.Decimal else if (number) KeyboardType.Number else KeyboardType.Text,
                        capitalization = if (phone) KeyboardCapitalization.None else capitalization,
                        imeAction = if (minLines > 1) ImeAction.Default else imeAction
                    ),
                    keyboardActions = KeyboardActions(onAny = { onIme() }),
                    modifier = Modifier.fillMaxWidth().focusRequester(focusRequester).onFocusChanged {
                        if (focused && !it.isFocused) onBlur()
                        focused = it.isFocused
                    }.semantics { contentDescription = label ?: placeholder }   // what the field is, for TalkBack
                )
            }
        }
        if (bad) Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            MIcon("alert", G.err, 18.dp, 2f)
            Text(error!!, style = ui(13.5f, 500, G.err))
        }
    }
}

/** A row in a sheet's action list: an icon in a pale tile, a label; red for destructive actions. */
@Composable
fun ActionRow(icon: String, label: String, onClick: () -> Unit, danger: Boolean = false, trailing: (@Composable () -> Unit)? = null) {
    val c = if (danger) G.err else G.ink
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.Button, onClick = onClick).padding(start = 4.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(12.dp)).background((if (danger) c else G.cobalt).copy(alpha = .12f)), contentAlignment = Alignment.Center) {
            MIcon(icon, if (danger) c else G.cobalt, 20.dp, 2f)
        }
        Text(label, style = ui(15.5f, 500, c), modifier = Modifier.weight(1f))
        trailing?.invoke()
    }
}

/** A white list group with hairlines between rows (prototype .lgroup in the glass look). */
@Composable
fun ListBox(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Column(modifier.fillMaxWidth().clip(shape).background(G.glass(.6f)).border(1.dp, G.rim, shape).padding(horizontal = 12.dp), content = content)
}

@Composable
fun Hairline() = Box(Modifier.fillMaxWidth().height(1.dp).background(G.ink.copy(alpha = .08f)))

/** The on/off switch: 46 × 28, a 22 dp white knob; blue when on. */
@Composable
fun GSwitch(on: Boolean) {
    Box(Modifier.size(46.dp, 28.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt else G.ink.copy(alpha = .14f)).padding(3.dp),
        contentAlignment = if (on) Alignment.CenterEnd else Alignment.CenterStart) {
        Box(Modifier.size(22.dp).dropShadow(CircleShape, Shadow(3.dp, Color(0x40101828), offset = DpOffset(0.dp, 1.dp))).clip(CircleShape).background(Color.White))
    }
}

/** A dashed glass button: the "add" row and tile of the glass design (prototype .gl-dash / .gl-tile). */
fun Modifier.dashedGlass(corner: Dp): Modifier = this
    .clip(RoundedCornerShape(corner))
    .background(G.glass(.28f))
    .drawBehind {
        val w = 1.33.dp.toPx()
        drawRoundRect(G.cobalt.copy(alpha = .45f), Offset(w / 2, w / 2), Size(size.width - w, size.height - w), CornerRadius(corner.toPx()),
            style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
    }

/** A small count pill next to a section title. */
@Composable
fun CountPill(n: Int) {
    Text("$n", style = uz.metrx.app.ui.theme.num(12f, 600, G.ink2), modifier = Modifier.clip(CircleShape).background(G.ink.copy(alpha = .06f)).padding(horizontal = 8.dp, vertical = 3.dp))
}

@Composable
fun VSpace(h: Dp) = Spacer(Modifier.height(h))

@Composable
fun Modifier.a11y(label: String) = this.semantics { contentDescription = label }

@Composable
fun Dot(color: Color, size: Dp) = Canvas(Modifier.size(size)) { drawCircle(color) }

@Composable
fun HSpacer(w: Dp) = Spacer(Modifier.width(w))
