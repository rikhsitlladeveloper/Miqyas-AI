package uz.metrx.app.ui.auth

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.Au
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.PlexMono
import uz.metrx.app.ui.theme.au
import uz.metrx.app.ui.theme.mono
import uz.metrx.app.ui.theme.tr

/* Pieces of the sign-in screens (prototype modules/auth.css). */

enum class BtnKind { PRIMARY, OUTLINE }

@Composable
fun AuButton(label: String, onClick: () -> Unit, kind: BtnKind = BtnKind.PRIMARY, enabled: Boolean = true, fontSize: Float = 16f,
             modifier: Modifier = Modifier, leading: (@Composable () -> Unit)? = null, trailing: (@Composable () -> Unit)? = null) {
    val shape = RoundedCornerShape(12.dp)
    val base = modifier.fillMaxWidth().heightIn(min = 52.dp)
    val styled = when (kind) {
        // the shadow stays in the chain whatever [enabled] is: adding it to a button already on screen made the button lose
        // its fill ("Boshlash" looked disabled while it worked), as GBtn did before
        BtnKind.PRIMARY -> base.dropShadow(shape, Shadow(14.dp, if (enabled) Au.cobalt.copy(alpha = .22f) else Color.Transparent, offset = DpOffset(0.dp, 6.dp)))
            .clip(shape).background(Au.cobalt)
        BtnKind.OUTLINE -> base.clip(shape).background(Color.White).border(1.5.dp, Au.line, shape)
    }
    Row(
        styled.alpha(if (enabled) 1f else .42f).pressable(onClick = { if (enabled) onClick() }, pressedScale = .98f).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
    ) {
        leading?.invoke()
        Text(label, style = au(fontSize, 600, if (kind == BtnKind.PRIMARY) Color.White else Au.ink), textAlign = TextAlign.Center)
        trailing?.invoke()
    }
}

/** The Google "G", drawn from the prototype's 18 × 18 SVG. */
@Composable
fun GoogleLogo(size: androidx.compose.ui.unit.Dp = 20.dp) {
    val parts = remember {
        listOf(
            "M9 3.48c1.69 0 2.83.73 3.48 1.34l2.54-2.48C13.46.89 11.43 0 9 0 5.48 0 2.44 2.02.96 4.96l2.91 2.26C4.6 5.05 6.62 3.48 9 3.48z" to Color(0xFFEA4335),
            "M17.64 9.2c0-.74-.06-1.28-.19-1.84H9v3.34h4.96c-.1.83-.64 2.08-1.84 2.92l2.84 2.2c1.7-1.57 2.68-3.88 2.68-6.62z" to Color(0xFF4285F4),
            "M3.88 10.78A5.54 5.54 0 0 1 3.58 9c0-.62.11-1.22.29-1.78L.96 4.96A9 9 0 0 0 0 9c0 1.45.35 2.82.96 4.04l2.92-2.26z" to Color(0xFFFBBC05),
            "M9 18c2.43 0 4.47-.8 5.96-2.18l-2.84-2.2c-.76.53-1.78.9-3.12.9-2.38 0-4.4-1.57-5.12-3.74L.97 13.04C2.45 15.98 5.48 18 9 18z" to Color(0xFF34A853)
        ).map { (d, c) -> PathParser().parsePathString(d).toPath() to c }
    }
    Canvas(Modifier.size(size)) {
        val k = this.size.width / 18f
        scale(k, k, pivot = Offset.Zero) { parts.forEach { (p, c) -> drawPath(p, c) } }
    }
}

/** Shows "90 123 45 67" while the field keeps only digits. */
private object PhoneGroups : VisualTransformation {
    private val breaks = intArrayOf(2, 5, 7)
    override fun filter(text: AnnotatedString): TransformedText {
        val d = text.text
        val sb = StringBuilder()
        d.forEachIndexed { i, c -> if (i in breaks) sb.append(' '); sb.append(c) }
        val map = object : OffsetMapping {
            override fun originalToTransformed(offset: Int) = offset + breaks.count { it < offset && it < d.length }
            override fun transformedToOriginal(offset: Int): Int {
                var o = offset
                for (b in breaks) if (b + breaks.indexOf(b) < offset) o--
                return o.coerceIn(0, d.length)
            }
        }
        return TransformedText(AnnotatedString(sb.toString()), map)
    }
}

enum class FieldKind { TEXT, PHONE, PASSWORD }

/** A labelled field with a native keyboard (prototype .auf / .aubox): blue ring when focused, red when wrong. */
@Composable
fun AuField(
    label: String, value: String, onValue: (String) -> Unit, kind: FieldKind = FieldKind.TEXT,
    placeholder: String = "", error: String? = null, showError: Boolean = false, onBlur: () -> Unit = {},
    imeAction: ImeAction = ImeAction.Next, onIme: () -> Unit = {}, focusRequester: FocusRequester = remember { FocusRequester() },
    trailingLabel: (@Composable () -> Unit)? = null
) {
    var focused by remember { mutableStateOf(false) }
    var showPw by remember { mutableStateOf(false) }
    val bad = showError && error != null
    val shape = RoundedCornerShape(12.dp)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, style = au(13.5f, 600, Au.ink2), modifier = Modifier.weight(1f))
            if (kind == FieldKind.PASSWORD) Text(tr(if (showPw) "pw.hide" else "pw.show"), style = au(13.5f, 600, Au.cobalt),
                modifier = Modifier.clickable(role = Role.Button) { showPw = !showPw }.padding(horizontal = 10.dp, vertical = 6.dp))
            trailingLabel?.invoke()
        }
        // focus: a 1px blue ring around the blue border plus a 4px pale halo outside it (box-shadow in the prototype)
        val edge = if (bad) G.err else if (focused) Au.cobalt else Au.line
        val halo = if (bad) G.errWash else Au.wash
        Row(
            Modifier.fillMaxWidth()
                .drawBehind {
                    if (focused) {
                        val o = 4.dp.toPx()
                        drawRoundRect(halo, Offset(-o / 2, -o / 2), Size(size.width + o, size.height + o), CornerRadius(12.dp.toPx() + o / 2), style = Stroke(o))
                    }
                }
                .clip(shape).background(Color.White).border(if (focused) 2.5.dp else 1.5.dp, edge, shape)
                .heightIn(min = 56.dp).padding(start = if (kind == FieldKind.PHONE) 6.dp else 14.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            when (kind) {
                FieldKind.PHONE -> Row(
                    Modifier.height(42.dp).clip(RoundedCornerShape(8.dp)).background(Color(0xFFF1F4FB)).padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) { UzFlag(); Text("+998", style = mono(15f, 600)) }
                FieldKind.PASSWORD -> MIcon("lock", if (focused) Au.cobalt else Au.ink3, 22.dp, 1.8f)
                FieldKind.TEXT -> MIcon("user", if (focused) Au.cobalt else Au.ink3, 22.dp, 1.8f)
            }
            val style = if (kind == FieldKind.PHONE) TextStyle(fontFamily = PlexMono, fontWeight = FontWeight.SemiBold, fontSize = androidx.compose.ui.unit.TextUnit(22f, androidx.compose.ui.unit.TextUnitType.Sp), color = Au.ink, letterSpacing = androidx.compose.ui.unit.TextUnit(.01f, androidx.compose.ui.unit.TextUnitType.Em))
                        else au(16f, 500, Au.ink)
            Box(Modifier.weight(1f).padding(vertical = 8.dp)) {
                if (value.isEmpty()) Text(placeholder, style = style.copy(color = Au.ink3, fontWeight = FontWeight.Normal))
                BasicTextField(
                    value = value,
                    onValueChange = { v -> onValue(if (kind == FieldKind.PHONE) normalisePhone(v) else v) },
                    singleLine = true,
                    textStyle = style,
                    cursorBrush = SolidColor(Au.cobalt),
                    visualTransformation = when {
                        kind == FieldKind.PHONE -> PhoneGroups
                        kind == FieldKind.PASSWORD && !showPw -> PasswordVisualTransformation('•')
                        else -> VisualTransformation.None
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = when (kind) { FieldKind.PHONE -> KeyboardType.Phone; FieldKind.PASSWORD -> KeyboardType.Password; else -> KeyboardType.Text },
                        capitalization = if (kind == FieldKind.TEXT) KeyboardCapitalization.Words else KeyboardCapitalization.None,
                        autoCorrectEnabled = false, imeAction = imeAction
                    ),
                    keyboardActions = KeyboardActions(onAny = { onIme() }),
                    modifier = Modifier.fillMaxWidth().focusRequester(focusRequester).onFocusChanged {
                        if (focused && !it.isFocused) onBlur()
                        focused = it.isFocused
                    }.semantics { contentDescription = label }   // what the field is, for TalkBack
                )
            }
            if (kind == FieldKind.TEXT && value.isNotEmpty()) Box(
                Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { onValue(""); focusRequester.requestFocus() },
                contentAlignment = Alignment.Center
            ) { PathIcon("M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 1 1 0-17zM9 9l6 6M15 9l-6 6", Au.ink3, 22.dp, 1.8f) }
        }
        if (bad) Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            MIcon("alert", G.err, 18.dp, 2f)
            Text(error!!, style = au(13.5f, 500, G.err))
        }
    }
}

/** Typing or pasting "+998 90 123 45 67" keeps only the 9 local digits. */
private fun normalisePhone(v: String): String {
    var d = v.filter { it.isDigit() }
    if (d.length > 9 && d.startsWith("998")) d = d.substring(3)
    return d.take(9)
}

@Composable
fun UzFlag() {
    Canvas(Modifier.size(22.dp, 16.dp)) {
        val w = size.width; val h = size.height; val r = CornerRadius(2.5f * w / 22f)
        clipRoundRect(r) {
            drawRect(Color.White)
            drawRect(Color(0xFF1E9FC7), size = Size(w, h * 5f / 16f))
            drawRect(Color(0xFF2DA84F), Offset(0f, h * 11f / 16f), Size(w, h * 5f / 16f))
            drawRect(Color(0xFFD8343C), Offset(0f, h * 5f / 16f), Size(w, h * .8f / 16f))
            drawRect(Color(0xFFD8343C), Offset(0f, h * 10.2f / 16f), Size(w, h * .8f / 16f))
        }
        drawRoundRect(Color(0x240B1226), cornerRadius = r, style = Stroke(1f))
    }
}

private fun DrawScope.clipRoundRect(r: CornerRadius, block: DrawScope.() -> Unit) {
    val p = Path().apply { addRoundRect(androidx.compose.ui.geometry.RoundRect(0f, 0f, size.width, size.height, r)) }
    clipPath(p) { block() }
}

/** "Davom etib, [Foydalanish shartlari] va ..." with the bracketed parts underlined. */
@Composable
fun Terms(modifier: Modifier = Modifier) {
    val raw = tr("au.terms")
    val text = buildAnnotatedString {
        var rest = raw
        while (true) {
            val a = rest.indexOf('['); val b = rest.indexOf(']', a + 1)
            if (a < 0 || b < 0) { append(rest); break }
            append(rest.substring(0, a))
            withStyle(SpanStyle(color = Au.ink2, fontWeight = FontWeight.Medium, textDecoration = TextDecoration.Underline)) { append(rest.substring(a + 1, b)) }
            rest = rest.substring(b + 1)
        }
    }
    Text(text, style = au(12f, 400, Au.ink3, 1.45f), textAlign = TextAlign.Center, modifier = modifier.fillMaxWidth())
}

/** "Hisobingiz bormi?  Kirish" */
@Composable
fun AuRow(lead: String, link: String, onLink: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Text(lead, style = au(14.5f, 400, Au.ink2))
        Spacer(Modifier.width(6.dp))
        Text(link, style = au(14.5f, 600, Au.cobalt), modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onLink).padding(horizontal = 4.dp, vertical = 12.dp))
    }
}

@Composable
fun ColumnScope.AuHeading(title: String, lead: String?) {
    Text(title, style = au(26f, 700, Au.ink, 1.2f, -.012f))
    if (lead != null) Text(lead, style = au(15f, 400, Au.ink2, 1.45f), modifier = Modifier.padding(top = 0.dp))
}
