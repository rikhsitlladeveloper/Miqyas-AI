package uz.metrx.app.voice

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UxIcon

/**
 * The hold-to-talk mic of a size field (UX upgrades §9): hold and say the size, let go, and the number goes into the
 * field ([onValue] gets millimetres and the words heard). The first hold without the voice pack opens its Wi-Fi sheet;
 * the first hold with it asks for the microphone.
 */
@Composable
fun VoiceMic(modifier: Modifier = Modifier, onValue: (Int, String) -> Unit) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = VoicePacks.langOf(app.settings.lang)
    val take by rememberUpdatedState(onValue)
    var listening by remember { mutableStateOf(false) }
    var words by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    fun hasMic() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (!ok) app.say("ux.v.micDenied", kind = ToastKind.ERROR) else scope.launch { VoiceRec.preload(ctx, lang) }
    }
    val ready = VoicePacks.ready(ctx, lang)
    // the model loads while the size is looked at, so the first hold answers at once
    LaunchedEffect(lang, ready) { if (ready && hasMic()) VoiceRec.preload(ctx, lang) }
    DisposableEffect(Unit) { onDispose { VoiceRec.cancel() } }

    fun down(): Boolean {
        when {
            VoicePacks.progress.containsKey(lang) -> { app.say("ux.v.still", kind = ToastKind.INFO); return false }
            !VoicePacks.ready(ctx, lang) -> { app.sheet = Sheet.VoicePack; return false }
            !hasMic() -> { ask.launch(Manifest.permission.RECORD_AUDIO); return false }
        }
        listening = true; words = ""
        app.haptic(Hap.TICK)
        scope.launch {
            VoiceRec.start(ctx, lang, onPartial = { words = it }, onFinal = { t ->
                listening = false
                val mm = VoiceNum.toMm(t, lang)
                when {
                    mm != null -> take(mm, t)
                    t.isBlank() || t == "[unk]" -> app.say("ux.micNothing", kind = ToastKind.INFO)
                    else -> app.say("ux.micNone", "t" to t, kind = ToastKind.ERROR)
                }
            }, onError = { listening = false; app.say("ux.v.err", kind = ToastKind.ERROR) })
        }
        return true
    }

    val pulse = rememberInfiniteTransition(label = "mic").animateFloat(1f, 1.04f, infiniteRepeatable(tween(520), RepeatMode.Reverse), label = "micPulse")
    val shape = RoundedCornerShape(16.dp)
    Column(modifier) {
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp)
            .graphicsLayer { if (listening) { scaleX = pulse.value; scaleY = pulse.value } }
            .clip(shape).background(if (listening) Color(0xFFDC2626) else G.ink).border(1.dp, if (listening) Color(0xFFDC2626) else G.ink, shape)
            .semantics { role = Role.Button; contentDescription = app.t("ux.mic") }
            .pointerInput(lang) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    if (down()) { waitForUpOrCancellation(); VoiceRec.stop() }
                }
            }.padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
            UxIcon("mic", G.solid, 22.dp, 2.2f)
            Text(if (listening) (if (words.isNotBlank()) "«$words»" else tr("ux.micRec")) else tr("ux.mic"), style = ui(14.5f, 800, G.solid, 1.15f), maxLines = 2,
                overflow = TextOverflow.Ellipsis)
        }
        if (listening) Text(tr("ux.micRelease"), style = ui(11.5f, 600, G.ink2), modifier = Modifier.padding(top = 4.dp, start = 4.dp))
    }
}

/** The voice pack's first-use sheet (§9): "Ovoz paketi (50 MB) — Wi-Fi da yuklab olish", with "Keyinroq". */
@Composable
fun VoicePackSheet() {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val lang = VoicePacks.langOf(app.settings.lang)
    val prog = VoicePacks.progress[lang]
    GlassSheet(tr("ux.v.title"), { app.sheet = null }, footer = {
        GBtn(if (prog != null) tr("ux.v.loading", "p" to (prog * 100).toInt()) else tr("ux.v.dl"), { startPack(app, ctx, lang) }, icon = if (prog != null) null else "save", enabled = prog == null)
        GBtn(tr("ux.v.later"), { app.sheet = null }, Btn.SECONDARY)
    }) {
        Text(tr("ux.v.lead"), style = ui(14.5f, 400, G.ink2, 1.45f))
        PackRow(lang)
    }
}

/** The pack's line: what it is and its state, with a progress bar while it downloads. */
@Composable
fun PackRow(lang: String) {
    val ctx = LocalContext.current
    val prog = VoicePacks.progress[lang]
    val ready = VoicePacks.ready(ctx, lang)
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        UxIcon("wifi", G.cobalt, 22.dp, 2f)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(tr(if (ready) "ux.v.row" else "ux.v.pack"), style = ui(14.5f, 700, G.ink, 1.3f))
            Text(when {
                ready -> tr("ux.v.ok", "l" to tr(if (lang == "ru") "ux.v.ru" else "ux.v.uz"))
                prog != null -> if (prog >= .9f) tr("ux.v.unzip") else tr("ux.v.loading", "p" to (prog * 100).toInt())
                else -> tr("ux.v.once")
            }, style = ui(12.5f, 400, if (ready) G.green else G.ink2, 1.4f))
            if (prog != null) Box(Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)).background(G.ink.copy(alpha = .1f))) {
                Box(Modifier.fillMaxWidth(prog.coerceIn(.02f, 1f)).height(6.dp).clip(RoundedCornerShape(3.dp)).background(G.cobalt))
            }
        }
    }
}

/** Starts the pack's download (Wi-Fi only); says when it is ready or why it could not. */
fun startPack(app: uz.metrx.app.ui.App, ctx: android.content.Context, lang: String) {
    VoicePacks.download(ctx.applicationContext, lang, app.scope) { err ->
        if (err == null) { app.haptic(Hap.CONFIRM); if (app.sheet == Sheet.VoicePack) app.sheet = null; app.say("ux.v.ready") }
        else app.say(err, kind = if (err == "ux.v.noWifi") ToastKind.INFO else ToastKind.ERROR)
    }
}
