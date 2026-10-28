package uz.metrx.app.ui.rooms

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uz.metrx.app.core.Laser
import uz.metrx.app.geo.ReErr
import uz.metrx.app.geo.STYLES
import uz.metrx.app.geo.bigWall
import uz.metrx.app.geo.fieldErr
import uz.metrx.app.geo.fillStandard
import uz.metrx.app.geo.isOpenKind
import uz.metrx.app.geo.pkSteps
import uz.metrx.app.geo.stdVals
import uz.metrx.app.geo.stepChips
import uz.metrx.app.geo.styleId
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import kotlin.random.Random

/*
 * The floating style window and the size steps (room editor v2, 27.10 (2)): dropping or placing an item opens a card
 * over the dimmed plan with its styles drawn as front views, the last style first with "Yana shu"; then the sizes one
 * per step — a big drawing with the asked edge in blue, chips with the style's standard ("st."), a big mm field that
 * opens the keypad, Lazer and Ovoz, Orqaga / Standart / Keyingi (Qo‘yish on the last step). The keypad itself
 * ([KeypadOverlay]) is the mockup's: digits, laser, voice and the reason a value is refused.
 */

/** A step's title and the line under it (the mockup's stepMeta). */
@Composable
private fun stepWords(f: String, kind: String, style: String, rh: Int): Pair<String, String> = when (f) {
    "w" -> tr("re.f.w") to tr(if (kind == "door") "re.fd.wDoor" else "re.fd.wWin")
    "h" -> when { style == "balcony" -> tr("re.f.hDoor") to tr("re.fd.hBal"); kind == "door" -> tr("re.f.h") to tr("re.fd.hDoor")
        style == "pano" -> tr("re.f.h") to tr("re.fd.hPano", "r" to mm(rh)); else -> tr("re.f.h") to tr("re.fd.hWin") }
    "sill" -> tr("re.f.sill") to tr("re.fd.sill")
    "dw" -> tr("re.f.dw") to tr("re.fd.dw")
    "ww" -> tr("re.f.ww") to tr("re.fd.ww")
    "wh" -> tr("re.f.wh") to tr("re.fd.wh")
    "pw" -> tr("re.f.w") to tr(if (kind == "rad") "re.fd.pwRad" else "re.fd.pwAc")
    else -> tr("re.f.ph") to tr("re.fd.ph")
}

/** A step problem in words. */
fun App.errText(e: ReErr, wall: String): String = t(e.key, *(e.args.map { it.key to mm(it.value) } + ("w" to wall)).toTypedArray())

/** The style card's line: its note, the standard size, a window's sill. */
private fun App.cardLine(kind: String, id: String, rh: Int): String {
    val st = uz.metrx.app.geo.styleOf(kind, id); val v = stdVals(kind, st, rh)
    var s = if (kind == "window" && id == "pano") mm(v["w"] ?: 0) + " × " + t("re.toCeil") else valsLine(kind, id, v)
    if (kind == "window" && v["sill"] != null) s += " · " + t("re.sillV", "v" to mm(v["sill"]!!))
    if (kind == "window" && id == "pano") s += " · " + t("re.sillV", "v" to "0")
    return (styleNote(kind, id)?.let { "$it · " } ?: "") + s
}

/**
 * The laser for a size: a real ZB-08 gives its next reading; the simulator the newest reading not used yet, else one
 * near [hint]; with no laser the radar opens (the session waits behind it).
 */
fun App.laserFor(scope: CoroutineScope, hint: Int, onBusy: (Boolean) -> Unit, ok: (Int) -> Unit) {
    if (laser.isReal) { onBusy(true); laser.await(onCancel = { onBusy(false) }) { mm -> onBusy(false); ok(mm) }; return }
    if (settings.laser != Laser.CONNECTED) { push(Route.LaserRadar); return }
    val r = settings.readings.lastOrNull { it.used == null && it.src != "manual" }
    if (r != null) { settings.markReadingUsed(r.id, t("re.title")); ok(r.mm); return }
    scope.launch { onBusy(true); delay(700); onBusy(false); ok(((hint + Random.nextInt(-9, 10)) / 1).coerceAtLeast(0)) }
}

@Composable
private fun CloseX(onClick: () -> Unit) {
    Box(Modifier.size(40.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).semantics { contentDescription = "×" }.clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center) { ReIcon("close", G.ink2, 17.dp, 2.2f) }
}

@Composable
private fun Btn2(label: String, icon: String?, modifier: Modifier = Modifier, primary: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(modifier.heightIn(min = 50.dp).clip(shape).background(if (primary) (if (enabled) G.cobalt else G.cobalt.copy(alpha = .15f)) else chipBg)
        .border(1.dp, if (primary) Color.Transparent else G.rim, shape).clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        if (icon != null) ReIcon(icon, if (primary) Color.White else G.ink, 18.dp)
        Text(label, style = ui(13.5f, 700, if (primary) (if (enabled) Color.White else G.ink3) else G.ink, 1.2f), textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** The style window / size steps over the whole screen. */
@Composable
fun BoxScope.PickWindow(s: ReSession) {
    val app = LocalApp.current
    val pk = s.pk ?: return
    val r = s.room ?: return
    val rh = roomH(r)
    val L = app.wallL(r, pk.wall)
    Box(Modifier.fillMaxSize().background(Color(0x6B0F172A)).clickable(remember { MutableInteractionSource() }, null) {
        // outside the card: "Bekor" while picking a style; nothing in the size steps (a typed number is not lost)
        if (pk.phase == "style") { s.pk = null; app.haptic(Hap.TICK) } else app.haptic(Hap.TICK)
    })
    Box(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 12.dp, vertical = 16.dp), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().widthIn(max = 460.dp).shadow(24.dp, RoundedCornerShape(28.dp)).clip(RoundedCornerShape(28.dp)).background(G.solid)
            .clickable(remember { MutableInteractionSource() }, null) {}.verticalScroll(rememberScrollState()).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (pk.phase == "style") StylePhase(s, pk, rh) else SizePhase(s, pk, rh, L)
        }
    }
}

@Composable
private fun StylePhase(s: ReSession, pk: Pick, rh: Int) {
    val app = LocalApp.current
    val k = pk.kind
    val last = if (pk.mode == "new") s.last[k] else null
    val list = (STYLES[k] ?: emptyList()).sortedByDescending { if (last != null && it.id == last.first) 1 else 0 }
    val cur = when (val b = pk.base) { is uz.metrx.app.data.Opening -> styleId(b); is uz.metrx.app.data.SitePoint -> styleId(b); else -> null }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        KindBadge(k, 36.dp)
        Column(Modifier.weight(1f)) {
            Text(tr("re.styleT", "n" to app.kindName(k), "w" to pk.wall), style = ui(16f, 800, G.ink, 1.2f))
            Text(tr(if (pk.mode == "new") "re.styleSubNew" else "re.styleSubRe"), style = ui(12f, 500, G.ink2, 1.3f))
        }
        CloseX { s.pk = null; app.haptic(Hap.TICK) }
    }
    if (last != null) {
        Column(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(18.dp)).background(G.cobalt).clickable(role = Role.Button) { app.pkAgain(s) }
            .padding(horizontal = 12.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReIcon("copy", Color.White, 19.dp)
                Text(tr("re.again", "v" to app.valsLine(k, last.first, last.second)), style = ui(15.5f, 800, Color.White), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(tr("re.againSub", "n" to app.styleName(k, last.first)), style = ui(11.5f, 600, Color.White.copy(alpha = .85f)), textAlign = TextAlign.Center)
        }
        Text(tr("re.orOther"), style = ui(11.5f, 700, G.ink3), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
    list.chunked(2).forEach { row ->
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { st ->
                val isL = last != null && st.id == last.first
                val on = pk.mode != "new" && cur == st.id
                val shape = RoundedCornerShape(18.dp)
                Column(Modifier.weight(1f).fillMaxHeight().clip(shape).background(chipBg).border(if (isL || on) 2.5.dp else 1.dp, if (isL || on) G.cobalt else G.rim, shape)
                    .clickable(role = Role.Button) { app.pkStyle(s, st.id) }.padding(6.dp)) {
                    Box(Modifier.fillMaxWidth().height(78.dp).clip(RoundedCornerShape(13.dp)).background(RP.elev)) {
                        val u = LocalDensity.current.density
                        Canvas(Modifier.fillMaxSize()) { styleThumb(k, st.id, stdVals(k, st, rh), u) }
                        if (isL || on) Text(tr(if (isL) "re.tagLast" else "re.tagNow"), style = ui(10.5f, 800, Color.White), modifier = Modifier.padding(4.dp)
                            .clip(RoundedCornerShape(10.dp)).background(G.cobalt).padding(horizontal = 8.dp, vertical = 2.dp))
                    }
                    Text(app.styleName(k, st.id), style = ui(13f, 800, G.ink, 1.2f), modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp))
                    Text(app.cardLine(k, st.id, rh), style = num(11f, 500, G.ink2).copy(lineHeight = androidx.compose.ui.unit.TextUnit(13.5f, androidx.compose.ui.unit.TextUnitType.Sp)),
                        modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 2.dp, bottom = 2.dp))
                }
            }
            if (row.size == 1) Spacer(Modifier.weight(1f))
        }
    }
    Btn2(tr("common.cancel"), null, Modifier.fillMaxWidth()) { s.pk = null; app.haptic(Hap.TICK) }
}

@Composable
private fun SizePhase(s: ReSession, pk: Pick, rh: Int, L: Int) {
    val app = LocalApp.current
    val k = pk.kind; val st = pk.style ?: return
    val steps = pkSteps(k, st); val n = steps.size; val i = pk.step.coerceIn(0, n - 1); val f = steps[i]
    val err = fieldErr(k, st, pk.v, f, L, rh)
    val (title, desc) = stepWords(f, k, st, rh)
    val chips = stepChips(f, k, st, rh)
    val cur = pk.v[f]
    val lastStep = i == n - 1
    val tm = rememberTextMeasurer()
    val u = LocalDensity.current.density
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    if (s.kp == null) uz.metrx.app.laser.LaserSink { mm -> s.pk = s.pk?.copy(v = (s.pk?.v ?: emptyMap()) + (f to mm), note = app.t("re.laserGot", "v" to mm(mm)), flash = pk.flash + 1); app.haptic(Hap.CONFIRM); true }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        KindBadge(k, 36.dp)
        Column(Modifier.weight(1f)) {
            Text(app.kindName(k) + " · " + app.styleName(k, st), style = ui(16f, 800, G.ink, 1.2f), maxLines = 2)
            Text(tr("re.stepSub", "w" to pk.wall, "i" to i + 1, "n" to n), style = ui(12f, 500, G.ink2))
        }
        CloseX { s.pk = null; app.haptic(Hap.TICK) }
    }
    Box(Modifier.fillMaxWidth().height(if (androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp < 700) 132.dp else 176.dp).clip(RoundedCornerShape(18.dp)).background(RP.elev)) {
        val ceil = tr("re.ceil")
        Canvas(Modifier.fillMaxSize()) { pkDraw(k, st, pk.v, f, rh, err != null, ceil, tm, u) }
    }
    @OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
    androidx.compose.foundation.layout.FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        steps.forEachIndexed { j, x ->
            if (j > 0) Text("→", style = ui(12f, 700, G.ink3))
            Text(stepWords(x, k, st, rh).first, style = ui(12f, if (j == i) 800 else 700, if (j == i) G.cobalt2 else if (j < i) G.ink2 else G.ink3))
        }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        steps.indices.forEach { j -> Box(Modifier.height(7.dp).width(if (j == i) 22.dp else 7.dp).clip(RoundedCornerShape(4.dp)).background(if (j == i) G.cobalt else if (j < i) G.cobalt.copy(alpha = .45f) else G.ink.copy(alpha = .12f))) }
    }
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, style = ui(17f, 800, G.ink, 1.2f))
        Text(desc + if (st == "balcony") " · " + tr("re.sillV", "v" to mm((pk.v["h"] ?: 0) - (pk.v["wh"] ?: 0))) else "", style = ui(13f, 400, G.ink2, 1.3f))
    }
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        chips.chips.forEach { x ->
            val on = cur == x
            Row(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.cobalt else chipBg).border(1.dp, if (on) Color.Transparent else G.rim, RoundedCornerShape(12.dp))
                .clickable(role = Role.Button) { s.pk = pk.copy(v = pk.v + (f to x), note = null); app.haptic(Hap.TICK) }.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(mm(x), style = num(13.5f, 800, if (on) Color.White else G.ink))
                if (x == chips.std) Text(tr("re.std"), style = ui(10f, 700, (if (on) Color.White else G.ink).copy(alpha = .7f)))
            }
        }
    }
    val glow = remember { Animatable(0f) }
    LaunchedEffect(pk.flash) { if (pk.flash > 0) { glow.snapTo(1f); glow.animateTo(0f, tween(1100)) } }
    val fshape = RoundedCornerShape(20.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 62.dp).clip(fshape).background(lerp(G.glass(.9f), G.greenWash, glow.value))
        .border(2.dp, if (err != null) G.err else lerp(G.cobalt, G.green, glow.value), fshape).clickable(role = Role.Button) { openPkKeypad(app, s, title) }
        .semantics { contentDescription = title }.padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(mm(cur ?: 0), style = num(32f, 800, G.ink), modifier = Modifier.weight(1f, false))
        Text(tr("u.mm"), style = ui(18f, 700, G.ink2))
        Spacer(Modifier.weight(1f))
        ReIcon("kbd", G.cobalt2, 24.dp)
    }
    if (err != null) Text(app.errText(err, pk.wall), style = ui(12.5f, 600, G.err, 1.3f), modifier = Modifier.padding(horizontal = 4.dp))
    else if (pk.note != null) Text(pk.note, style = ui(12.5f, 700, G.green, 1.3f), modifier = Modifier.padding(horizontal = 4.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        val on = app.settings.laser == Laser.CONNECTED || app.laser.isReal
        val ls = RoundedCornerShape(12.dp)
        Row(Modifier.weight(.8f).heightIn(min = 48.dp).clip(ls).background(if (on) G.greenWash else G.cobalt.copy(alpha = .1f)).border(1.5.dp, if (on) G.green else G.cobalt, ls)
            .clickable(role = Role.Button, enabled = !busy) {
                app.haptic(Hap.TICK)
                app.laserFor(scope, cur ?: 0, { busy = it }) { v -> val p2 = s.pk ?: return@laserFor
                    s.pk = p2.copy(v = p2.v + (f to v), note = app.t("re.laserGot", "v" to mm(v)), flash = p2.flash + 1); app.haptic(Hap.CONFIRM) }
            }.padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
            ReIcon(if (on) "laser" else "bt", if (on) G.green else G.cobalt2, 18.dp)
            Text(tr(if (busy) "ux.lz.busy" else if (on) "re.laserOn" else "re.laser"), style = ui(13.5f, 700, if (on) G.green else G.cobalt2), maxLines = 1)
        }
        uz.metrx.app.voice.VoiceMic(Modifier.weight(1.2f)) { v, words -> val p2 = s.pk ?: return@VoiceMic
            s.pk = p2.copy(v = p2.v + (f to v), note = app.t("re.voiceGot", "t" to words), flash = p2.flash + 1); app.haptic(Hap.CONFIRM) }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Btn2(tr("re.back"), "back") {
            s.pk = if (pk.step > 0) pk.copy(step = pk.step - 1, note = null) else pk.copy(phase = "style", mode = if (pk.mode == "resize") "retype" else pk.mode, note = null)
            app.haptic(Hap.TICK)
        }
        Btn2(tr("re.stdBtn"), null) { s.pk = pk.copy(v = fillStandard(k, st, pk.v, pk.step, rh)); app.pkFinish(s) }
        Btn2(tr(if (lastStep) (if (pk.mode == "new") "re.put" else "common.save") else "common.next"), null, Modifier.weight(1f), primary = true, enabled = err == null) {
            if (err != null) { app.haptic(Hap.WARN); return@Btn2 }
            if (!lastStep) { s.pk = pk.copy(step = pk.step + 1, note = null); app.haptic(Hap.TICK) } else app.pkFinish(s)
        }
    }
}

/** The size step's field: the keypad with this step's value. */
private fun openPkKeypad(app: App, s: ReSession, title: String) {
    val pk = s.pk ?: return
    val f = pkField(pk) ?: return
    s.kp = Kp(app.kindName(pk.kind) + " · " + app.styleName(pk.kind, pk.style ?: "") + " · " + title.lowercase(), pk.v[f] ?: 0, if (f == "sill" || f == "ph") 0 else 100, 99_999) { v ->
        val p2 = s.pk ?: return@Kp
        s.pk = p2.copy(v = p2.v + (f to v), note = null, flash = p2.flash + 1)
    }
}

/* ---------------- the keypad ---------------- */

@Composable
fun BoxScope.KeypadOverlay(s: ReSession) {
    val app = LocalApp.current
    val k = s.kp ?: return
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    uz.metrx.app.laser.LaserSink { mm -> k.v = mm.toString(); k.err = null; k.note = app.t("re.laserGot", "v" to mm(mm)); app.haptic(Hap.CONFIRM); true }
    fun ok() {
        if (k.v.isEmpty()) { s.kp = null; return }
        val v = k.v.toInt()
        if (v < k.lo || v > k.hi) { k.err = app.t("re.kpBad", "v" to mm(v), "a" to mm(k.lo), "b" to mm(k.hi)); app.haptic(Hap.WARN); return }
        s.kp = null; k.ok(v)
    }
    Box(Modifier.fillMaxSize().background(Color(0x14000000)).clickable(remember { MutableInteractionSource() }, null) { s.kp = null })
    Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().clickable(remember { MutableInteractionSource() }, null) {}
        .background(if (RP.dark) Color(0xFF1C2131) else Color(0xFFD3D6DE)).navigationBarsPadding().padding(start = 8.dp, end = 8.dp, bottom = 10.dp)) {
        Row(Modifier.fillMaxWidth().padding(bottom = 8.dp).background(G.solid).padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f).padding(start = 6.dp)) {
                Text(k.lab, style = ui(12f, 700, G.ink2), maxLines = 2)
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(if (k.v.isNotEmpty()) mm(k.v.toInt()) else mm(k.cur), style = num(30f, 800, if (k.v.isNotEmpty()) G.ink else G.ink3))
                    Text(" " + tr("u.mm"), style = ui(15f, 600, G.ink2), modifier = Modifier.padding(bottom = 4.dp))
                }
                val v = k.v.toIntOrNull()
                val amb = k.big && bigWall(v)
                Text(k.err ?: if (amb) app.t("re.bigWallS", "v" to mm(v!!)) else k.note ?: app.t("re.kpRange", "a" to mm(k.lo), "b" to mm(k.hi)),
                    style = ui(12f, if (k.err != null || amb || k.note != null) 800 else 600, when { k.err != null -> G.err; amb -> G.amberInk; k.note != null -> G.green; else -> G.ink2 }), maxLines = 2)
            }
            Text(tr("dzc.done"), style = ui(15f, 800, Color.White), modifier = Modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(G.cobalt)
                .clickable(role = Role.Button, onClick = ::ok).padding(horizontal = 18.dp, vertical = 14.dp))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 6.dp)) {
            val on = app.settings.laser == Laser.CONNECTED || app.laser.isReal
            Row(Modifier.weight(.8f).heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.greenWash else G.cobalt.copy(alpha = .12f))
                .border(1.5.dp, if (on) G.green else G.cobalt, RoundedCornerShape(12.dp)).clickable(role = Role.Button, enabled = !busy) {
                    app.laserFor(scope, k.cur, { busy = it }) { v -> k.v = v.toString(); k.err = null; k.note = app.t("re.laserGot", "v" to mm(v)); app.haptic(Hap.CONFIRM) }
                }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                ReIcon(if (on) "laser" else "bt", if (on) G.green else G.cobalt2, 18.dp)
                Text(tr(if (busy) "ux.lz.busy" else if (on) "re.laserOn" else "re.laser"), style = ui(13.5f, 700, if (on) G.green else G.cobalt2))
            }
            uz.metrx.app.voice.VoiceMic(Modifier.weight(1.2f)) { v, words -> k.v = v.toString(); k.err = null; k.note = app.t("re.voiceGot", "t" to words) }
        }
        listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("", "0", "bk")).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 6.dp)) {
                row.forEach { x ->
                    Box(Modifier.weight(1f).height(46.dp).clip(RoundedCornerShape(8.dp)).background(if (x.isEmpty() || x == "bk") Color.Transparent else G.solid)
                        .semantics { contentDescription = if (x == "bk") "⌫" else x }
                        .clickable(enabled = x.isNotEmpty(), role = Role.Button) {
                            if (x == "bk") k.v = k.v.dropLast(1) else if (k.v.length < 6) { if (k.v == "0") k.v = ""; k.v += x } else app.haptic(Hap.WARN)
                            k.err = null; k.note = null
                        }, contentAlignment = Alignment.Center) {
                        if (x == "bk") ReIcon("bksp", G.ink, 24.dp) else Text(x, style = ui(22f, 500, G.ink))
                    }
                }
            }
        }
    }
}
