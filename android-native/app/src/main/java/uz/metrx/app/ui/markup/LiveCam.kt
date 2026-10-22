package uz.metrx.app.ui.markup

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.data.MkEl
import uz.metrx.app.data.PhotoFiles
import uz.metrx.app.data.uid
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.dimMax
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.editor.errText
import uz.metrx.app.ui.editor.unitName
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.io.File
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.random.Random

/*
 * The live camera (prototype camera.js PAGES.liveCam): draw a line on the live view, take its length from the laser or
 * type it, then save the frame. The app never works a distance out from the picture: the number is the laser's or typed.
 * The line stays where it was drawn on the screen (no AR tracking), so the saved frame is the lasting record.
 */

private val LC_BG = Color(0xFF0B1020)
private val LC_VIEW = Color(0xFF161D30)
private val LC_MUTED = Color(0xFFC9D1E3)
private val LC_RED = Color(0xFFD92D20)

/** The live camera's line (as parts of the view's width and height), its length and where the length came from. */
class LiveLine {
    var line by mutableStateOf<List<Float>?>(null)
    var v by mutableStateOf<Int?>(null)
    var src by mutableStateOf<String?>(null)
}

@Composable
fun LiveCamScreen() {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val en = LocalLang.current == Lang.EN
    val bt = app.settings.laser == Laser.CONNECTED
    val s = app.live
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var err by rememberSaveable { mutableStateOf<String?>(null) }
    var on by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> granted = ok; if (!ok) err = "denied" }
    LaunchedEffect(Unit) { if (!granted) ask.launch(Manifest.permission.CAMERA) }
    var view by remember { mutableStateOf<PreviewView?>(null) }
    val scope = rememberCoroutineScope()
    // the photo is being written: a second tap on Save does not save it twice
    var saving by remember { mutableStateOf(false) }
    val stateText = when {
        s.v != null -> tr(if (s.src == "laser") "cm.s2l" else "cm.s2m")
        s.line != null -> tr(if (bt) "cm.s1" else "cm.s1off")
        else -> tr("cm.s0")
    }
    Column(Modifier.fillMaxSize().background(LC_BG).statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(start = 6.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button) { app.pop() }, contentAlignment = Alignment.Center) { MIcon("x", Color.White, 22.dp, 2f) }
            Text(tr("cm.live"), style = ui(17f, 700, Color.White), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = .14f)).clickable { app.sheet = Sheet.Device }.padding(horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                MIcon(if (bt) "bt" else "btoff", if (bt) Color.White else Color(0xFFFFD7A8), 16.dp, 2f)
                Text(tr(if (bt) "dev.conn" else "dev.disc"), style = ui(12.5f, 500, if (bt) Color.White else Color(0xFFFFD7A8)), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (err != null) {
            Column(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 28.dp, vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
                Box(Modifier.size(72.dp).clip(RoundedCornerShape(22.dp)).background(Color.White.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("camera", Color.White, 32.dp, 2f) }
                Text(tr("cm.errT"), style = ui(20f, 800, Color.White))
                Text(tr(if (err == "denied") "cm.errDenied" else "cm.errNone"), style = ui(14.5f, 400, LC_MUTED, 1.5f).copy(textAlign = TextAlign.Center), modifier = Modifier.widthIn(max = 300.dp))
                GBtn(tr("cm.photo"), { app.mk.launch?.invoke(PhotoTarget(null, null), true) }, icon = "camera", fill = false)
            }
            return@Column
        }
        Box(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 10.dp).clip(RoundedCornerShape(18.dp)).background(LC_VIEW)) {
            if (granted) {
                val owner = LocalLifecycleOwner.current
                AndroidView(factory = { c ->
                    PreviewView(c).apply {
                        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                        view = this
                        val fut = ProcessCameraProvider.getInstance(c)
                        fut.addListener({
                            runCatching {
                                val pr = fut.get()
                                val pv = Preview.Builder().build().also { p -> p.surfaceProvider = surfaceProvider }
                                val sel = if (pr.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) CameraSelector.DEFAULT_BACK_CAMERA else CameraSelector.DEFAULT_FRONT_CAMERA
                                pr.unbindAll(); pr.bindToLifecycle(owner, sel, pv); on = true
                            }.onFailure { err = "none" }
                        }, ContextCompat.getMainExecutor(c))
                    }
                }, modifier = Modifier.fillMaxSize())
                DisposableEffect(Unit) { onDispose { runCatching { ProcessCameraProvider.getInstance(ctx).get().unbindAll() } } }
            }
            LineLayer(s, on, en, app.unitName(), Modifier.fillMaxSize())
            if (on && s.line == null) Text(tr("cm.hint"), style = ui(13.5f, 500, Color.White).copy(textAlign = TextAlign.Center),
                modifier = Modifier.align(Alignment.TopCenter).padding(12.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LC_BG.copy(alpha = .72f)).padding(horizontal = 12.dp, vertical = 9.dp))
            if (!on) Text(tr("cm.starting"), style = ui(14f, 400, LC_MUTED), modifier = Modifier.align(Alignment.Center))
        }
        Text(stateText, style = ui(14f, 600, Color.White, 1.35f), modifier = Modifier.fillMaxWidth().heightIn(min = 30.dp).padding(start = 16.dp, end = 16.dp, top = 10.dp))
        Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("info", LC_MUTED, 16.dp, 2f); Text(tr("cm.steady"), style = ui(12.5f, 400, LC_MUTED, 1.4f), modifier = Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth().padding(10.dp, 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LcBtn("kbd", tr("ed2.manual"), s.line != null, false, Modifier.weight(1f)) { app.sheet = Sheet.LcManual }
            LcBtn("laser", tr("qc.measure"), s.line != null && bt, true, Modifier.weight(1.3f)) { s.v = 600 + Random.nextInt(7601); s.src = "laser" }
            LcBtn("save", tr("common.save"), s.v != null && on && !saving, false, Modifier.weight(1f)) {
                if (saving) return@LcBtn
                val pv = view ?: return@LcBtn; val ln = s.line ?: return@LcBtn; val v = s.v ?: return@LcBtn; val src = s.src
                val frame = pv.bitmap ?: run { app.say("mk.photoErr", kind = ToastKind.INFO); return@LcBtn }
                saving = true
                scope.launch {
                    val id = uid()
                    val saved = withContext(Dispatchers.IO) { PhotoFiles.save(ctx, id, frame, 78) }
                    if (saved == null) { saving = false; app.say("mk.photoErr", kind = ToastKind.INFO); return@launch }
                    val (path, w, h) = saved
                    val hh = (1000f * h / w)
                    val el = MkEl(uid(), "dim", listOf(listOf((ln[0] * 1000).roundToInt().toFloat(), (ln[1] * hh).roundToInt().toFloat()), listOf((ln[2] * 1000).roundToInt().toFloat(), (ln[3] * hh).roundToInt().toFloat())),
                        "red", v = v, src = if (src == "laser") "laser" else "manual")
                    val it = app.mk.addPhoto(PhotoTarget(null, null), id, path, w, h, listOf(el))
                    s.line = null; s.v = null; s.src = null
                    app.pop(); app.say("cm.saved"); app.push(Route.Markup(null, it.id))
                }
            }
        }
    }
}

@Composable
private fun LcBtn(icon: String, label: String, enabled: Boolean, pri: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Row(modifier.heightIn(min = 54.dp).alpha(if (enabled) 1f else .4f).clip(RoundedCornerShape(16.dp)).background(if (pri) uz.metrx.app.ui.theme.G.cobalt else Color.White.copy(alpha = .14f))
        .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        MIcon(icon, Color.White, 18.dp, 2f); Text(label, style = ui(15f, 700, Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The red line drawn over the live view, with its length (prototype lcLineSVG). */
@Composable
private fun LineLayer(s: LiveLine, on: Boolean, en: Boolean, m: String, modifier: Modifier) {
    val app = LocalApp.current
    val tm = rememberTextMeasurer()
    val density = androidx.compose.ui.platform.LocalDensity.current
    Canvas(modifier.pointerInput(on) {
        if (!on) return@pointerInput
        awaitEachGesture {
            val d = awaitFirstDown(); if (app.sheet != null) return@awaitEachGesture
            fun at(p: Offset) = listOf((p.x / size.width).coerceIn(.015f, .985f), (p.y / size.height).coerceIn(.015f, .985f))
            val a = at(d.position); s.line = listOf(a[0], a[1], a[0], a[1]); s.v = null; s.src = null
            while (true) {
                val ev = awaitPointerEvent(); val c = ev.changes.firstOrNull { it.id == d.id } ?: break
                if (!c.pressed) break
                c.consume(); val b = at(c.position); s.line = listOf(a[0], a[1], b[0], b[1])
            }
            s.line?.let { l -> if (hypot((l[2] - l[0]) * size.width, (l[3] - l[1]) * size.height) < 18 * density.density) s.line = null }
        }
    }) {
        val l = s.line ?: return@Canvas
        val dp = density.density
        val x1 = l[0] * size.width; val y1 = l[1] * size.height; val x2 = l[2] * size.width; val y2 = l[3] * size.height
        val dx = x2 - x1; val dy = y2 - y1; val len = hypot(dx, dy).takeIf { it > 0 } ?: 1f
        val nx = -dy / len * 9 * dp; val ny = dx / len * 9 * dp
        val path = Path().apply { moveTo(x1, y1); lineTo(x2, y2); moveTo(x1 - nx, y1 - ny); lineTo(x1 + nx, y1 + ny); moveTo(x2 - nx, y2 - ny); lineTo(x2 + nx, y2 + ny) }
        drawPath(path, Color.White, alpha = .85f, style = Stroke(6 * dp, cap = StrokeCap.Round))
        drawPath(path, LC_RED, style = Stroke(3 * dp, cap = StrokeCap.Round))
        val has = s.v != null
        val txt = if (has) fmtLen(s.v, app.settings.unit, en, full = true) + " " + m else "?"
        val lay = tm.measure(txt, TextStyle(fontFamily = PlexCond, fontWeight = FontWeight.Bold, fontSize = 17.sp))
        val tw = lay.size.width + 24 * dp; val mx = (x1 + x2) / 2; val ly = maxOf(18 * dp, (y1 + y2) / 2 - 26 * dp)
        drawRoundRect(if (has) LC_RED else Color.White, Offset(mx - tw / 2, ly - 15 * dp), Size(tw, 30 * dp), CornerRadius(15 * dp))
        drawRoundRect(LC_RED, Offset(mx - tw / 2, ly - 15 * dp), Size(tw, 30 * dp), CornerRadius(15 * dp), style = Stroke(1.5f * dp))
        drawText(lay, if (has) Color.White else Color(0xFFB42318), Offset(mx - lay.size.width / 2f, ly - lay.size.height / 2f))
    }
}

/** Typing the line's length (prototype SHEETS.lcManual). */
@Composable
fun LcManualSheet() {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val s = app.live
    var v by rememberSaveable { mutableStateOf(s.v?.let { fmtLen(it, app.settings.unit, en, full = true) } ?: "") }
    var tried by remember { mutableStateOf(false) }
    val parsed = lenErr(v, dimMax("A"), app.settings.unit, en)
    val focus = remember { androidx.compose.ui.focus.FocusRequester() }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(300); runCatching { focus.requestFocus() } }
    fun save() { val ok = parsed as? Parsed.Ok; if (v.isBlank() || ok == null) { tried = true; return }; s.v = ok.value.toInt(); s.src = "manual"; app.sheet = null }
    GlassSheet(tr("cm.manT"), { app.sheet = null }, footer = { GBtn(tr("common.save"), { save() }) }) {
        NumField(tr("mk.value"), v, { v = it }, app.unitName(), errText(parsed), tried || v.isNotBlank(), imeAction = ImeAction.Done, onIme = { save() }, focusRequester = focus)
    }
}

/**
 * The phone's photo pickers, always ready (registered once at the app's root): the gallery, and the phone's own camera
 * app writing into the app's cache. The picture is then made upright and smaller, saved, and opened for drawing.
 */
@Composable
fun PhotoIntake(app: App) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var target by rememberSaveable { mutableStateOf<String?>(null) }   // "pid|wid", "|" for the Measure page
    fun tgt() = target?.split("|")?.let { PhotoTarget(it[0].ifEmpty { null }, it.getOrNull(1)?.ifEmpty { null }) }
    fun take(uri: Uri?) {
        val t = tgt() ?: return; target = null
        if (uri == null) return
        scope.launch {
            val id = uid()
            val saved = withContext(Dispatchers.IO) { PhotoFiles.decode(ctx, uri)?.let { PhotoFiles.save(ctx, id, it) } }
            if (saved == null) { app.say("mk.photoErr", kind = ToastKind.INFO); return@launch }
            val it = app.mk.addPhoto(t, id, saved.first, saved.second, saved.third)
            if (app.top is Route.LiveCam) app.pop()
            app.push(Route.Markup(t.pid, it.id))
        }
    }
    val camFile = remember { File(ctx.cacheDir, "camera/shot.jpg") }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { take(it) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok -> take(if (ok) Uri.fromFile(camFile) else null) }
    fun openCamera() = runCatching {
        camFile.parentFile?.mkdirs(); camFile.delete()
        camera.launch(FileProvider.getUriForFile(ctx, ctx.packageName + ".files", camFile))
    }.onFailure { target = null; app.say("cm.errNone", kind = ToastKind.INFO) }
    // the app also uses the camera itself (the live camera), so Android lets the camera app start only once that is allowed
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> if (ok) openCamera() else { target = null; app.say("cm.errDenied", kind = ToastKind.INFO) } }
    app.mk.launch = { t, cam ->
        target = (t.pid ?: "") + "|" + (t.wid ?: "")
        if (cam) {
            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) openCamera() else ask.launch(Manifest.permission.CAMERA)
        } else runCatching { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            .onFailure { target = null; app.say("mk.photoErr", kind = ToastKind.INFO) }
    }
}
