package uz.metrx.app.ui.rooms

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uz.metrx.app.core.Laser
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.parseDec
import uz.metrx.app.geo.unitDecimals
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.editor.english
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UxIcon
import uz.metrx.app.ui.ux.coachSpot
import kotlin.random.Random

/*
 * One size of the room-shape flow, as the UX upgrades' size steps (§6, §9, §10): a big number field with the phone's own
 * number keyboard, the laser button ("Lazerni ulash" opens the radar, "Lazer · o‘lchash" measures) and the hold-to-talk
 * mic under it; a laser or voice value lights the field green with a confirm tick, a wrong number buzzes.
 */

/** A typed length in mm in [unit] (null when empty, unreadable or zero). */
fun parseLen(s: String, unit: LenUnit): Int? = (parseDec(s, unitDecimals(unit)) as? Parsed.Ok)?.value?.toInt()?.takeIf { it > 0 }

/** The unit's short word: mm, sm, m. */
@Composable
fun unitWordOf(unit: LenUnit) = tr(when (unit) { LenUnit.CM -> "u.cm"; LenUnit.MM -> "u.mm"; else -> "u.m" })

/** A length in the unit's words, "3 400" mm or "3,4" m. */
fun lenWords(mm: Int, unit: LenUnit, en: Boolean): String = if (unit == LenUnit.MM) fmtMm(mm.toDouble()) else fmtLen(mm, unit, en)

/**
 * The field and its tools. [text] what is typed (in [unit]); [fresh]: the value was put in for the maker (the last
 * height, a size opened again) and the first key replaces it; [hint] shows when empty; [issue] a red line under it;
 * [flash] grows by one for each laser or voice value; [heard] the voice's words with the value it replaced.
 */
@Composable
fun SizeField(key: Any, label: String, help: String, text: String, fresh: Boolean, hint: Int, unit: LenUnit, issue: String?, flash: Int,
              heard: Pair<String, String>?, onText: (String) -> Unit, onNext: () -> Unit, onLaser: (Int) -> Unit, onVoice: (Int, String) -> Unit, onUnVoice: () -> Unit) {
    val app = LocalApp.current
    val en = app.english()
    val uw = unitWordOf(unit)
    val fr = remember { FocusRequester() }
    // each step opens with its field focused and the phone's number keyboard up (also after Back closed it)
    val kb = androidx.compose.ui.platform.LocalSoftwareKeyboardController.current
    LaunchedEffect(key) { runCatching { fr.requestFocus() }; kb?.show() }
    LaunchedEffect(issue) { if (issue != null) app.haptic(Hap.WARN) }
    val glow = remember { Animatable(0f) }
    LaunchedEffect(flash) { if (flash > 0) { glow.snapTo(1f); glow.animateTo(0f, tween(1100)) } }
    // the value put in for the maker is selected, so the first key typed replaces it
    var tfv by remember(key) { mutableStateOf(TextFieldValue(text, if (fresh) TextRange(0, text.length) else TextRange(text.length))) }
    if (tfv.text != text) tfv = TextFieldValue(text, if (fresh) TextRange(0, text.length) else TextRange(text.length))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = ui(20f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        if (heard != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.greenWash).padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            UxIcon("mic", G.green, 18.dp, 2.2f)
            Text(tr("ux.micGot", "t" to heard.second, "v" to text + " " + uw), style = ui(13f, 600, G.ink, 1.3f), modifier = Modifier.weight(1f))
            Text(tr("ux.cancel"), style = ui(14f, 800, G.cobalt2), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp))
                .clickable(role = Role.Button, onClick = onUnVoice).padding(horizontal = 12.dp, vertical = 12.dp))
        } else Text(help, style = ui(13f, 400, G.ink2, 1.35f))
        val bad = issue != null
        val shape = RoundedCornerShape(18.dp)
        val green = Color(0xFF22C55E)
        Row(Modifier.fillMaxWidth().heightIn(min = 68.dp)
            .dropShadow(shape, Shadow(18.dp, green.copy(alpha = .55f * glow.value)))
            .clip(shape).background(lerp(G.glass(.85f), G.greenWash, glow.value))
            .border(2.dp, if (bad) G.err else lerp(G.cobalt, green, glow.value), shape).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) {
                if (text.isEmpty()) Text(if (unit == LenUnit.MM) fmtMm(hint.toDouble()) else fmtField(hint, unit, en), style = num(32f, 600, Color(0xFFA7B0C0)))
                BasicTextField(tfv, { v ->
                    val clean = v.text.filter { it.isDigit() || (unit != LenUnit.MM && (it == ',' || it == '.')) }.take(if (unit == LenUnit.MM) 5 else 8)
                    tfv = v.copy(text = clean, selection = if (clean == v.text) v.selection else TextRange(clean.length))
                    if (clean != text) onText(clean)
                }, Modifier.fillMaxWidth().focusRequester(fr).semantics { contentDescription = label }, textStyle = num(32f, 700, G.ink), singleLine = true,
                    cursorBrush = SolidColor(G.cobalt),
                    keyboardOptions = KeyboardOptions(keyboardType = if (unit == LenUnit.MM) KeyboardType.Number else KeyboardType.Decimal, imeAction = ImeAction.Next),
                    keyboardActions = KeyboardActions(onNext = { onNext() }, onDone = { onNext() }))
            }
            Text(uw, style = ui(17f, 700, G.ink3))
        }
        if (issue != null) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { MIcon("alert", G.err, 18.dp, 2f); Text(issue, style = ui(13.5f, 600, G.err, 1.35f)) }
        LaserMic(hint, unit, onLaser, onVoice)
    }
}

/**
 * The laser button and the mic, always under the field (UX upgrades §6). Without a laser the button opens the radar;
 * with one it takes the next measurement (the simulator: the newest reading not used yet, else one near [hint]).
 */
@Composable
private fun LaserMic(hint: Int, unit: LenUnit, onLaser: (Int) -> Unit, onVoice: (Int, String) -> Unit) {
    val app = LocalApp.current
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    uz.metrx.app.laser.LaserSink { mm -> busy = false; onLaser(mm); true }
    fun read() {
        if (busy) return
        if (app.laser.isReal) { busy = true; app.laser.await(onCancel = { busy = false }) { mm -> busy = false; onLaser(mm) }; return }
        val r = app.settings.readings.lastOrNull { it.used == null && it.src != "manual" }
        if (r != null) { app.settings.markReadingUsed(r.id, app.t("rsh.title")); onLaser(r.mm); return }
        scope.launch { busy = true; delay(900); busy = false; onLaser(((hint + Random.nextInt(-120, 121)) / 10) * 10) }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val on = app.settings.laser == Laser.CONNECTED
        val lshape = RoundedCornerShape(16.dp)
        Row(Modifier.weight(1f).heightIn(min = 56.dp).clip(lshape).background(if (on) G.green.copy(alpha = .14f) else G.cobalt.copy(alpha = .1f))
            .border(1.5.dp, if (on) G.green else G.cobalt, lshape)
            .clickable(role = Role.Button, enabled = !busy) { app.haptic(Hap.TICK); if (on) read() else app.push(Route.LaserRadar) }
            .padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
            MIcon(if (on) "laser" else "bt", if (on) G.green else G.cobalt2, 20.dp, 2.2f)
            Text(tr(if (busy) "ux.lz.busy" else if (on) "ux.lz.measure" else "ux.lz.connect"), style = ui(14.5f, 800, if (on) G.green else G.cobalt2, 1.15f), maxLines = 2)
        }
        uz.metrx.app.voice.VoiceMic(Modifier.weight(1f).coachSpot("size"), onVoice)
    }
}
