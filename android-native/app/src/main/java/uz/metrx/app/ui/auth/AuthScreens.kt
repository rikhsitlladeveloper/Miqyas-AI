package uz.metrx.app.ui.auth

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Num
import uz.metrx.app.core.Phone
import uz.metrx.app.ui.components.LogoTile
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.Au
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.LocalSettings
import uz.metrx.app.ui.theme.PlexMono
import uz.metrx.app.ui.theme.au
import uz.metrx.app.ui.theme.mono
import uz.metrx.app.ui.theme.tr

/**
 * Google Play / App Store v1 (founder, 25 and 28 Oct 2026): no accounts. The app opens straight into use: the welcome
 * screen has only "Boshlash" (the builder's name and phone, both optional, kept on this phone), then the trade. The
 * sign-up, log-in and Google screens stay in the code for a later version, unreachable while this is false (as iPhone
 * AuthFlags.accounts).
 */
object AuthFlags { const val accounts = false }

/** Where the sign-in flow goes next. Sign-up and log-in are screens only for now: their buttons explain that. */
interface AuthNav {
    fun signUp()
    fun logIn()
    fun local()
    fun back()
    fun done()
    fun soon()
}

private val RISE = CubicBezierEasing(.3f, .7f, .2f, 1f)

/** auRise: a group fades in and slides up 10 dp, .45 s, with a delay, when the welcome follows the opening animation. */
@Composable
private fun Modifier.rise(play: Boolean, delayMs: Int): Modifier {
    val a = remember { Animatable(if (play) 0f else 1f) }
    LaunchedEffect(play) { if (play) a.animateTo(1f, tween(450, delayMs, RISE)) }
    return this.alpha(a.value).offset(y = (10 * (1 - a.value)).dp)
}

/** Welcome: the sample room card, the promise and "Boshlash" (with [AuthFlags.accounts]: three sign-in buttons and
 *  "continue without an account"). */
@Composable
fun WelcomeScreen(nav: AuthNav, fromSplash: Boolean) {
    val settings = LocalSettings.current
    val lang = LocalLang.current
    var menu by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler(enabled = menu) { menu = false }
    BoxWithConstraints(Modifier.fillMaxSize().background(Color.White)) {
        val cardH = (maxHeight - 600.dp).coerceIn(158.dp, 330.dp)
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().verticalScroll(rememberScrollState())
                .padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(13.dp)
        ) {
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).rise(fromSplash, 0), verticalAlignment = Alignment.CenterVertically) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LogoTile(28.dp, 8.dp, Color(0xFF374FDD))
                    Spacer(Modifier.size(9.dp))
                    Text("METRX", style = mono(17f, 700, Au.ink, .2f))
                }
                Spacer(Modifier.weight(1f))
                Row(
                    Modifier.heightIn(min = 44.dp).clip(CircleShape).background(Color.White).border(1.5.dp, Au.line, CircleShape)
                        .clickable(role = Role.Button) { menu = !menu }.padding(start = 12.dp, end = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    MIcon("globe", Au.cobalt, 18.dp, 1.8f)
                    Text(lang.shortName, style = au(13.5f, 600))
                    PathIcon("M6 9.5l6 6 6-6", Au.ink2, 18.dp, 1.8f)
                }
            }
            Box(Modifier.rise(fromSplash, 0)) { SampleCard(cardH, lang) }
            Column(Modifier.rise(fromSplash, 80), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(tr("au.welcome"), style = au(27f, 700, Au.ink, 1.18f, -.015f), modifier = Modifier.padding(top = 4.dp))
                Text(tr("au.tagline"), style = au(15f, 400, Au.ink2, 1.45f))
            }
            if (AuthFlags.accounts) {
                Column(Modifier.padding(top = 4.dp).rise(fromSplash, 160), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    AuButton(tr("au.signup"), nav::signUp)
                    AuButton(tr("au.login"), nav::logIn, BtnKind.OUTLINE)
                    AuButton(tr("au.google"), nav::soon, BtnKind.OUTLINE, fontSize = 15f, leading = { GoogleLogo() })
                }
                SkipCard(nav::local, Modifier.rise(fromSplash, 160))
                Spacer(Modifier.weight(1f, fill = false))
                Terms(Modifier.padding(top = 2.dp).rise(fromSplash, 160))
            } else StartBlock(nav::local, Modifier.padding(top = 4.dp).rise(fromSplash, 160))
        }
        if (menu) LanguageMenu(lang, onPick = { settings.setLanguage(it); menu = false }, onDismiss = { menu = false })
    }
}

@Composable
private fun LanguageMenu(cur: Lang, onPick: (Lang) -> Unit, onDismiss: () -> Unit) {
    Box(Modifier.fillMaxSize().clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onDismiss)) {
        val shape = RoundedCornerShape(14.dp)
        Column(
            Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(top = 58.dp, end = 20.dp).width(IntrinsicSize.Max).widthIn(min = 210.dp)
                .dropShadow(shape, Shadow(32.dp, Color(0x2E0B1226), offset = DpOffset(0.dp, 12.dp)))
                .clip(shape).background(Color.White).border(1.dp, Au.hair, shape).padding(6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Lang.entries.forEach { l ->
                val on = l == cur
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).background(if (on) Au.wash else Color.White)
                        .clickable(role = Role.RadioButton) { onPick(l) }.padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(l.longName, style = au(15f, if (on) 600 else 400, if (on) Au.cobalt2 else Au.ink), modifier = Modifier.weight(1f).padding(end = 10.dp))
                    if (on) MIcon("check", Au.cobalt2, 18.dp, 2f)
                }
            }
        }
    }
}

/** The sample room of the whole prototype: 5,00 × 4,00 m, a window on the left wall, a door, one laser line. */
@Composable
private fun SampleCard(height: androidx.compose.ui.unit.Dp, lang: Lang) {
    val shape = RoundedCornerShape(16.dp)
    val m = tr("u.m"); val m2 = tr("u.m2")
    Column(
        Modifier.fillMaxWidth().height(height)
            .dropShadow(shape, Shadow(18.dp, Color(0x123355B4), offset = DpOffset(0.dp, 6.dp)))
            .clip(shape).background(Color.White).border(1.5.dp, Au.line, shape)
    ) {
        Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.heightIn(min = 22.dp).clip(CircleShape).background(Au.chip).padding(horizontal = 9.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(Modifier.size(6.dp).clip(CircleShape).background(Au.cobalt))
                Text(tr("au.sample").uppercase(), style = mono(10.5f, 600, Au.ink, .08f))
            }
            Spacer(Modifier.weight(1f))
            Text(tr("au.height").uppercase() + " ", style = mono(10.5f, 500, Au.cobalt, .08f))
            Text("${Num.len(3000, lang)} $m", style = mono(10.5f, 500, Au.cobalt, .02f))
        }
        PlanDrawing(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 8.dp, vertical = 2.dp), lang, m)
        Box(Modifier.padding(horizontal = 12.dp).fillMaxWidth().height(1.dp).background(Au.hair))
        Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 9.dp)) {
            Text(tr("au.room").uppercase() + ": ", style = mono(10.5f, 600, Au.ink, .08f))
            Text("${Num.fixed(20.0, 2, lang)} $m2", style = mono(10.5f, 600, Au.cobalt, .02f))
            Spacer(Modifier.weight(1f))
            Text(tr("au.perim").uppercase() + ": ", style = mono(10.5f, 600, Au.ink, .08f))
            Text("${Num.len(18000, lang)} $m", style = mono(10.5f, 600, Au.cobalt, .02f))
        }
    }
}

@Composable
private fun PlanDrawing(modifier: Modifier, lang: Lang, m: String) {
    val tm = rememberTextMeasurer()
    val ink = Au.ink; val bl = Au.cobalt; val ln = Au.line
    val paths = remember {
        fun p(d: String) = PathParser().parsePathString(d).toPath()
        mapOf(
            "dimx" to p("M70 40V22M230 40V22M70 28H230M66 32l8-8M226 32l8-8"),
            "dimy" to p("M238 48H258M238 176H258M252 48V176M248 52l8-8M248 180l8-8"),
            "walls" to p("M190 176H230V48H70V176H160"),
            "arc" to p("M190 176A30 30 0 0 0 181.2 154.8")
        )
    }
    val lx = "${Num.len(5000, lang)} $m"; val ly = "${Num.len(4000, lang)} $m"
    Canvas(modifier) {
        // viewBox 0 0 300 190, preserveAspectRatio xMidYMid meet
        val k = minOf(size.width / 300f, size.height / 190f)
        translate((size.width - 300f * k) / 2f, (size.height - 190f * k) / 2f) {
            scale(k, k, pivot = Offset.Zero) {
                drawCircle(Au.plan, 22f, Offset(150f, 112f))
                drawLine(Color(0xFFDDE5EF), Offset(150f, 58f), Offset(150f, 168f), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 4f)))
                drawPath(paths.getValue("dimx"), ink, style = Stroke(1.2f))
                drawPath(paths.getValue("dimy"), ink, style = Stroke(1.2f))
                drawPath(paths.getValue("walls"), ink, style = Stroke(3.2f, cap = StrokeCap.Square))
                drawRect(Au.wash, Offset(66.5f, 84f), Size(7f, 42f))
                drawRect(bl, Offset(66.5f, 84f), Size(7f, 42f), style = Stroke(1.4f))
                drawLine(bl, Offset(70f, 84f), Offset(70f, 126f), 1.4f)
                drawLine(ink, Offset(160f, 176f), Offset(181.2f, 154.8f), 2.2f, cap = StrokeCap.Round)
                drawPath(paths.getValue("arc"), Color(0xFF8A97AD), style = Stroke(1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 3f))))
                drawLine(Color(0xFFB4C0D3), Offset(42f, 105f), Offset(62f, 105f), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(1.5f, 3f)))
                drawLine(bl, Offset(74f, 105f), Offset(228f, 105f), 1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f)))
                drawCircle(bl.copy(alpha = .2f), 7f, Offset(228f, 105f)); drawCircle(bl, 3.5f, Offset(228f, 105f))
                fun lab(text: String, c: Offset, rot: Float) = rotate(rot, c) {
                    drawRoundRect(Color.White, Offset(c.x - 29f, c.y - 10f), Size(58f, 20f), CornerRadius(3f))
                    drawRoundRect(ln, Offset(c.x - 29f, c.y - 10f), Size(58f, 20f), CornerRadius(3f), style = Stroke(1f))
                    val r = tm.measure(text, mono(11f, 500, ink), density = Density(1f, 1f))
                    drawText(r, topLeft = Offset(c.x - r.size.width / 2f, c.y - r.size.height / 2f))
                }
                lab(lx, Offset(150f, 28f), 0f)
                lab(ly, Offset(252f, 112f), 90f)
            }
        }
    }
}

/** v1's start: one button to the builder's details, and where everything is kept. */
@Composable
private fun StartBlock(onClick: () -> Unit, modifier: Modifier) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        AuButton(tr("fr.start"), onClick, trailing = { MIcon("chev", Color.White, 18.dp, 2f) })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("device", Au.ink2, 18.dp, 1.8f)
            Text(tr("au.skipNote"), style = au(13f, 400, Au.ink2, 1.4f), modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun SkipCard(onClick: () -> Unit, modifier: Modifier) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier.fillMaxWidth().clip(shape).background(Au.tint).border(1.5.dp, Au.line, shape).pressable(onClick, .99f)
            .padding(start = 12.dp, end = 10.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(Color.White).border(1.dp, Au.line, RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
            MIcon("device", Au.cobalt, 22.dp, 1.8f)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(tr("au.skip"), style = au(15f, 600))
                Text(tr("au.offTag").uppercase(), style = mono(10f, 600, Color.White, .08f),
                    modifier = Modifier.align(Alignment.CenterVertically).clip(RoundedCornerShape(4.dp)).background(Au.cobalt).padding(horizontal = 7.dp, vertical = 3.dp))
            }
            Text(tr("au.skipNote"), style = au(13f, 400, Au.ink2, 1.35f))
        }
        MIcon("chev", Au.cobalt, 18.dp, 2f)
    }
}

/* ---------- step pages: header with back, title and n/3, progress, body, footer ---------- */

@Composable
private fun AuPage(title: String, step: Int?, onBack: () -> Unit, footer: (@Composable () -> Unit)? = null,
                   bottomNote: (@Composable () -> Unit)? = null, body: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().background(Color.White).statusBarsPadding().navigationBarsPadding().imePadding()) {
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onBack), contentAlignment = Alignment.Center) {
                MIcon("back", Au.ink, 24.dp, 2f)
            }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(title, style = au(17f, 700), textAlign = TextAlign.Center)
                if (step != null) Text("$step/3", style = mono(12.5f, 400, Au.ink2))
            }
            Spacer(Modifier.size(48.dp))
        }
        if (step != null) Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            (1..3).forEach { i -> Box(Modifier.weight(1f).height(4.dp).clip(RoundedCornerShape(2.dp)).background(if (i <= step) Au.cobalt else Au.step)) }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Au.hair))
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 22.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp), content = body
        )
        if (footer != null) Column(Modifier.fillMaxWidth().background(Color.White)) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(Au.hair))
            Box(Modifier.padding(start = 20.dp, end = 20.dp, top = 10.dp, bottom = 12.dp)) { footer() }
        }
        val ime = WindowInsets.ime.getBottom(androidx.compose.ui.platform.LocalDensity.current) > 0
        if (bottomNote != null && !ime) Box(Modifier.padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 12.dp)) { bottomNote() }
    }
}

private val NextArrow = "M5 12h14M13 6l6 6-6 6"

/** Sign up, step 1: name and phone. Sending the code is not built yet, so the button explains that. */
@Composable
fun SignUpScreen(nav: AuthNav) {
    var name by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var tName by rememberSaveable { mutableStateOf(false) }
    var tPhone by rememberSaveable { mutableStateOf(false) }
    val phoneF = remember { FocusRequester() }
    val nErr = if (name.isBlank()) tr("bd.req") else null
    val pKey = Phone.errorKey(phone, true); val pErr = pKey?.let { tr(it) }
    val kb = LocalSoftwareKeyboardController.current
    AuPage(tr("au.signup"), 1, nav::back, bottomNote = { Terms() }) {
        AuHeading(tr("su.phoneTitle"), tr("su.phoneBody"))
        AuField(tr("su.name"), name, { name = it }, FieldKind.TEXT, tr("fr.namePh"), nErr, tName, { tName = true }, ImeAction.Next, { phoneF.requestFocus() })
        AuField(tr("su.phone"), phone, { phone = it }, FieldKind.PHONE, "90 123 45 67", pErr, tPhone, { tPhone = true }, ImeAction.Done, { kb?.hide() }, phoneF)
        AuButton(tr("su.sendCode"), { kb?.hide(); nav.soon() }, enabled = nErr == null && pErr == null,
            trailing = { PathIcon(NextArrow, Color.White, 18.dp, 1.8f) })
        AuRow(tr("su.have"), tr("au.login"), nav::logIn)
    }
}

/** Log in: phone and password, Google. Not built yet: the buttons explain that. */
@Composable
fun LogInScreen(nav: AuthNav) {
    var phone by rememberSaveable { mutableStateOf("") }
    var pw by rememberSaveable { mutableStateOf("") }
    var tPhone by rememberSaveable { mutableStateOf(false) }
    var tPw by rememberSaveable { mutableStateOf(false) }
    val pwF = remember { FocusRequester() }
    val pErr = Phone.errorKey(phone, true)?.let { tr(it) }
    val wErr = if (pw.isEmpty()) tr("pw.req") else null
    val kb = LocalSoftwareKeyboardController.current
    AuPage(tr("au.login"), null, nav::back) {
        Text(tr("li.title"), style = au(26f, 700, Au.ink, 1.2f, -.012f))
        AuField(tr("su.phone"), phone, { phone = it }, FieldKind.PHONE, "90 123 45 67", pErr, tPhone, { tPhone = true }, ImeAction.Next, { pwF.requestFocus() })
        AuField(tr("pw.label"), pw, { pw = it }, FieldKind.PASSWORD, "", wErr, tPw, { tPw = true }, ImeAction.Done, { kb?.hide() }, pwF)
        Row(Modifier.fillMaxWidth().offset(y = (-10).dp), horizontalArrangement = Arrangement.End) {
            Text(tr("li.forgot"), style = au(14.5f, 600, Au.cobalt), modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button) { nav.soon() }.padding(horizontal = 4.dp, vertical = 12.dp))
        }
        AuButton(tr("au.login"), { kb?.hide(); nav.soon() }, enabled = pErr == null && wErr == null)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f).height(1.dp).background(Au.hair)); Text(tr("au.or"), style = au(13f, 400, Au.ink3)); Box(Modifier.weight(1f).height(1.dp).background(Au.hair))
        }
        AuButton(tr("au.google"), nav::soon, BtnKind.OUTLINE, fontSize = 15f, leading = { GoogleLogo() })
        AuRow(tr("li.noAcc"), tr("au.signup"), nav::signUp)
    }
}

/** Continue without an account: the builder's name and phone for reports, kept on this phone only. */
@Composable
fun LocalScreen(nav: AuthNav, title: String? = null) {
    val settings = LocalSettings.current
    var name by rememberSaveable { mutableStateOf(settings.builderName) }
    var phone by rememberSaveable { mutableStateOf(Phone.digits(settings.builderPhone)) }
    var tName by rememberSaveable { mutableStateOf(false) }
    var tPhone by rememberSaveable { mutableStateOf(false) }
    val phoneF = remember { FocusRequester() }
    // both optional (store review: an app without accounts must not demand personal data); they only go on the PDF
    // quotes. A phone, when typed, must still be valid.
    val nErr: String? = null
    val pErr = Phone.errorKey(phone, false)?.let { tr(it) }
    val kb = LocalSoftwareKeyboardController.current
    val focus = LocalFocusManager.current
    val ok = nErr == null && pErr == null
    fun start() { kb?.hide(); focus.clearFocus(); settings.saveBuilder(name, phone); nav.done() }
    AuPage(title ?: tr(if (AuthFlags.accounts) "au.skip" else "fr.builderTitle"), null, nav::back, footer = { AuButton(if (title != null) tr("common.save") else tr("fr.start"), ::start, enabled = ok) }) {
        AuHeading(tr("fr.aboutTitle"), tr("fr.aboutBody"))
        AuField(tr("su.name"), name, { name = it }, FieldKind.TEXT, tr("fr.namePh"), nErr, tName, { tName = true }, ImeAction.Next, { phoneF.requestFocus() })
        AuField(tr("su.phone"), phone, { phone = it }, FieldKind.PHONE, "90 123 45 67", pErr, tPhone, { tPhone = true }, ImeAction.Done, { if (ok) start() else kb?.hide() }, phoneF)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("device", Au.ink2, 18.dp, 1.8f)
            Text(tr(if (AuthFlags.accounts) "fr.noAccount" else "au.skipNote"), style = au(13f, 400, Au.ink2, 1.4f))
        }
    }
}

/** The bottom sheet that says accounts are not ready yet (look of the prototype's .au-bs). */
@Composable
fun SoonSheet(onLocal: () -> Unit, onClose: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().background(Color(0x6B0B1226)).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose))
        val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth()
                .dropShadow(shape, Shadow(30.dp, Color(0x2E0B1226), offset = DpOffset(0.dp, (-10).dp)))
                .clip(shape).background(Color.White)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}   // taps on the sheet don't reach the scrim
                .navigationBarsPadding().padding(start = 24.dp, end = 24.dp, top = 10.dp, bottom = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(Modifier.padding(bottom = 10.dp).size(48.dp, 4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFFDAE1E9)))
            Box(Modifier.size(68.dp).clip(CircleShape).background(Au.wash).border(1.5.dp, Color(0xFFD6E2F4), CircleShape), contentAlignment = Alignment.Center) {
                MIcon("user", Au.cobalt, 40.dp, 1.6f)
            }
            Text(tr("nt.soonT"), style = au(22f, 700, Au.ink, 1.2f, -.01f), textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
            Text(tr("nt.soonB"), style = au(15f, 400, Au.ink2, 1.5f), textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 8.dp))
            AuButton(tr("au.skip"), onLocal)
            Text(tr("common.close"), style = au(15f, 600, Au.cobalt), modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onClose).padding(horizontal = 12.dp, vertical = 12.dp))
        }
    }
}
