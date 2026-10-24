package uz.metrx.app.ui.measure

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import uz.metrx.app.core.BRICK_LIMITS
import uz.metrx.app.core.BRICK_PRESETS
import uz.metrx.app.core.BrickSpec
import uz.metrx.app.core.CALC_SLOTS
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.core.brickCount
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Pending
import uz.metrx.app.data.Reading
import uz.metrx.app.data.dn
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.LaserButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.editor.errText
import uz.metrx.app.ui.editor.unitName
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.main.Tab
import uz.metrx.app.ui.report.fmtTime
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.random.Random

/*
 * The Measure page (prototype measure.js "one press + quick area", glass look): a meter with the laser's state and the
 * last reading, single or continuous measuring, five calculators fed by readings, the readings themselves (send one to
 * a room, delete it), manual entry, and the camera. Reached from Home's "O‘lchash" and "Kalkulyator" cards.
 */

private val NAVY = Color(0xFF0E1C36)
private val MUTED = Color(0xFFB7C3D9)
private val AMBER_RING = Color(0xFFFFB547)
private const val BRICK_ICON = "M3 6h8v5H3zM13 6h8v5h-8zM7 13h10v5H7z"

/** The calculator's state, kept while the app runs (prototype U.qc). */
class MeasureCalc {
    var tool by mutableStateOf("area")
    /** Per tool, the readings put into its slots (reading id and mm), null where still empty. */
    val vals = mapOf("area" to mutableStateListOf<Pair<String, Int>?>(), "wall" to mutableStateListOf(), "vol" to mutableStateListOf(), "sum" to mutableStateListOf(), "brick" to mutableStateListOf(),
        "sheet" to mutableStateListOf())
    var act by mutableStateOf<Int?>(null)
    var brickOpening by mutableStateOf(false)
    var cont by mutableStateOf(false)
    var live by mutableStateOf(false)
    var liveVal by mutableStateOf<Int?>(null)
    var showList by mutableStateOf(false)

    private fun slots() = CALC_SLOTS.getValue(tool).let { if (tool == "brick" && !brickOpening) it.take(2) else it }
    /** The slot the next reading goes into: the one picked, else the first empty one (prototype qcActive). */
    fun active(): Int? {
        val v = vals.getValue(tool); if (tool == "sum") return v.size
        val n = slots().size
        act?.let { if (it < n) return it }
        for (i in 0 until n) if (v.getOrNull(i) == null) return i
        return null
    }
    fun fill(r: Reading) {
        val v = vals.getValue(tool); val i = active() ?: return
        while (v.size <= i) v.add(null)
        v[i] = r.id to r.mm; act = null
    }
}

@Composable
fun MeasureScreen(calcTitle: Boolean) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val s = app.settings
    val c = app.calc
    val u = s.unit; val m = app.unitName()
    val on = s.laser == Laser.CONNECTED
    // the real laser measures on its own button, one press one reading: no continuous mode then
    val real = app.laser.isReal
    if (!on || real) c.live = false
    if (real) c.cont = false
    // continuous mode: the simulated laser keeps reporting a value that moves a little
    LaunchedEffect(c.live) {
        while (c.live) { c.liveVal = ((c.liveVal ?: Random.nextInt(600, 8200)) + Random.nextInt(-3, 4)).coerceIn(300, 9000); delay(400) }
    }
    val rs = s.readings.reversed()
    val last = if (on && c.cont && c.liveVal != null) c.liveVal else rs.firstOrNull()?.mm
    fun add(mm: Int, src: String) { val r = s.addReading(mm, src); c.fill(r) }
    // every real-laser measurement taken while this page is open is a reading here (and fills the calculator)
    uz.metrx.app.laser.LaserSink { mm -> add(mm, "laser"); true }
    // furniture makers have the sheets tool where builders have bricks; it is the advanced app's (simple mode has neither)
    val sheets = s.furniture && s.advanced
    LaunchedEffect(s.furniture, sheets) {
        if (sheets && c.tool == "brick") c.tool = "sheet"
        if ((s.furniture && c.tool == "brick") || (!sheets && c.tool == "sheet")) c.tool = "area"
    }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Text(tr(if (calcTitle) "gl.calc" else "tab.measure"), style = ui(36f, 800, G.ink, 1.15f, -.02f), modifier = Modifier.weight(1f), maxLines = 1)
                Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) { LaserButton { app.sheet = Sheet.Device } }
            }
            val scroll = rememberScrollState()
            // "Kalkulyator" opens the page at its tools row (prototype glScroll 'calc': the row 12 px from the top)
            var toolsY by remember { mutableIntStateOf(-1) }
            val gap = with(androidx.compose.ui.platform.LocalDensity.current) { 12.dp.roundToPx() }
            LaunchedEffect(calcTitle, toolsY) { if (calcTitle && toolsY >= 0) scroll.scrollTo(maxOf(0, toolsY - gap)) }
            Column(Modifier.weight(1f).verticalScroll(scroll).padding(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 110.dp + uz.metrx.app.ui.main.NAV_SPACE).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Meter(on, real, c, last, u, en, m)
                Box(Modifier.onGloballyPositioned { if (toolsY < 0) toolsY = it.positionInParent().y.toInt() }) { Tools(c) }
                CalcCard(c, u, en, m)
                if (rs.isNotEmpty() && c.vals.getValue(c.tool).none { it != null }) Text(tr("qc.pick"), style = ui(13f, 400, G.ink2, 1.4f))
                Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(horizontal = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("qc.readings"), style = ui(15f, 600), modifier = Modifier.weight(1f))
                    if (rs.isNotEmpty()) Text(tr(if (c.showList) "qc.hide" else "qc.list"), style = ui(14f, 500, G.cobalt),
                        modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { c.showList = !c.showList }.padding(horizontal = 6.dp, vertical = 10.dp))
                }
                if (rs.isEmpty()) Text(tr("qc.none"), style = ui(13f, 400, G.ink2, 1.4f))
                else Chips(rs, c, u, en)
                if (c.showList && rs.isNotEmpty()) ReadingList(rs, u, en, m)
                if (s.shots.isNotEmpty()) Shots(s.shots, u, en, m)
            }
        }
        FloatingFooter(Modifier.align(Alignment.BottomCenter).padding(bottom = uz.metrx.app.ui.main.NAV_SPACE - 12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.size(56.dp, 54.dp).clip(RoundedCornerShape(18.dp)).background(G.cobalt.copy(alpha = .12f)).pressable({ app.sheet = Sheet.CameraPick }, .96f, label = tr("cm.btn")),
                    contentAlignment = Alignment.Center) { MIcon("camera", G.cobalt, 20.dp, 2f) }
                Row(Modifier.height(54.dp).clip(RoundedCornerShape(18.dp)).background(G.cobalt.copy(alpha = .12f)).pressable({ app.sheet = Sheet.QmManual }, .97f).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
                    MIcon("kbd", G.cobalt, 18.dp, 2f); Text(tr("ed2.manual"), style = ui(16f, 700, G.cobalt), maxLines = 1)
                }
                when {
                    // two lines rather than "Lazerni …" when the phone's font is set large
                    !on -> GBtn(tr("qc.connect"), { app.openLaser() }, icon = "bt", modifier = Modifier.weight(1f), maxLines = 2)
                    c.cont -> GBtn(tr("qc.saveLive"), { c.liveVal?.let { add(it, "sim"); app.say("qm.saved") } }, icon = "save", enabled = c.liveVal != null, modifier = Modifier.weight(1f), maxLines = 2)
                    else -> GBtn(tr("qc.measure"), { if (real) app.laser.await { add(it, "laser") } else add(Random.nextInt(600, 8200), "sim") }, icon = "laser", modifier = Modifier.weight(1f), maxLines = 2)
                }
            }
        }
    }
}

@Composable
private fun Meter(on: Boolean, real: Boolean, c: MeasureCalc, last: Int?, u: LenUnit, en: Boolean, m: String) {
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(if (on && c.live) G.green else G.greyIcon))
            Text(tr(if (!on) "dev.disc" else if (c.live) "meas.live" else "meas.idle"), style = ui(12.5f, 600, G.ink2))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.Bottom) {
            Text(if (last != null) fmtLen(last, u, en, full = true) else "–,–––", style = ui(54f, 600, G.ink, 1f).copy(fontFamily = PlexCond), maxLines = 1)
            Text(m, style = ui(22f, 500, G.ink2, 1f).copy(fontFamily = PlexCond), modifier = Modifier.padding(start = 4.dp, bottom = 6.dp))
        }
        if (on && real) Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            MIcon("laser", G.cobalt, 18.dp, 2f); Text(tr("lz.press"), style = ui(13.5f, 500, G.ink2, 1.4f), modifier = Modifier.weight(1f))
        } else if (on) {
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                listOf(false to "meas.single", true to "meas.cont").forEach { (cont, k) ->
                    val sel = c.cont == cont; val sh = RoundedCornerShape(9.dp)
                    Box(Modifier.weight(1f).let { if (sel) it.dropShadow(sh, Shadow(3.dp, Color(0x24101828), offset = DpOffset(0.dp, 1.dp))) else it }.height(44.dp).clip(sh)
                        .background(if (sel) G.glass(.9f) else Color.Transparent).clickable(role = Role.Tab) { c.cont = cont; c.live = false }, contentAlignment = Alignment.Center) {
                        Text(tr(k), style = ui(14f, if (sel) 600 else 500, if (sel) G.ink else G.ink2))
                    }
                }
            }
            if (c.cont) Row(Modifier.fillMaxWidth().height(44.dp).clip(RoundedCornerShape(12.dp)).background(if (c.live) G.green.copy(alpha = .14f) else G.cobalt.copy(alpha = .1f))
                .clickable(role = Role.Button) { c.live = !c.live }, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("laser", if (c.live) G.green else G.cobalt, 18.dp, 2f)
                Text(tr(if (c.live) "qc.stop" else "qc.start"), style = ui(15f, 700, if (c.live) G.green else G.cobalt))
            }
        } else Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("btoff", G.amberInk, 18.dp, 2f); Text(tr("ms.discBody"), style = ui(13.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun Tools(c: MeasureCalc) {
    val s = LocalApp.current.settings
    // the fifth tool: bricks for builders, sheets for a furniture maker's advanced app, none in simple mode
    val fifth = if (!s.furniture) "brick" else if (s.advanced) "sheet" else null
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        (listOf("area" to "room", "wall" to "walls", "vol" to "cube", "sum" to "dim") + listOfNotNull(fifth?.let { it to "" })).forEach { (k, ic) ->
            val on = c.tool == k; val sh = RoundedCornerShape(12.dp)
            Column(Modifier.weight(1f).height(54.dp).let { if (on) it.dropShadow(sh, Shadow(12.dp, Color(0x401C4BD1), offset = DpOffset(0.dp, 4.dp))) else it }.clip(sh)
                .background(if (on) G.cobalt else G.idle(.55f)).border(if (on) 0.dp else 1.dp, if (on) Color.Transparent else G.idleRim, sh)
                .clickable(role = Role.Tab) { c.tool = k; c.act = null }.padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                val tint = if (on) Color.White else G.ink
                if (ic.isEmpty()) PathIcon(if (k == "sheet") uz.metrx.app.ui.furniture.SHEET_ICON else BRICK_ICON, tint, 18.dp, 2f) else MIcon(ic, tint, 18.dp, 2f)
                Text(tr("qc.$k"), style = ui(11.5f, 600, tint), maxLines = 1)
            }
        }
    }
}

/** The dark calculator card: slots, the result and Clear (prototype qcCalc). */
@Composable
private fun CalcCard(c: MeasureCalc, u: LenUnit, en: Boolean, m: String) {
    val app = LocalApp.current
    val v = c.vals.getValue(c.tool)
    fun g(i: Int) = v.getOrNull(i)?.second
    val act = c.active()
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(NAVY).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        @Composable fun slot(i: Int, lab: String, modifier: Modifier) {
            val x = v.getOrNull(i)
            Column(modifier.heightIn(min = 55.dp).clip(RoundedCornerShape(12.dp)).drawBehind {
                val r = CornerRadius(12.dp.toPx())
                if (x == null) drawRoundRect(Color.White.copy(alpha = .35f), size = size, cornerRadius = r, style = Stroke(1.33.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f))))
                else drawRoundRect(Color.White.copy(alpha = .1f), size = size, cornerRadius = r)
                if (act == i) drawRoundRect(AMBER_RING, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(11.dp.toPx()), style = Stroke(2.dp.toPx()))
            }.clickable(role = Role.Button) { c.act = i }.padding(vertical = 7.dp, horizontal = 4.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(if (x != null) fmtLen(x.second, u, en, full = true) else "?", style = ui(20f, 600, if (x != null) Color.White else MUTED, 1.1f).copy(fontFamily = PlexCond))
                Text(tr("qc.$lab"), style = ui(11f, 400, MUTED))
            }
        }
        @Composable fun op(t: String) = Text(t, style = ui(18f, 600, MUTED).copy(fontFamily = PlexCond))
        when (c.tool) {
            "sum" -> FlowRow2 {
                v.forEachIndexed { i, x -> if (i > 0) op("+")
                    Box(Modifier.clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = .1f)).clickable { v.removeAt(i) }.padding(horizontal = 10.dp, vertical = 7.dp)) {
                        Text(fmtLen(x!!.second, u, en, full = true), style = ui(20f, 600, Color.White).copy(fontFamily = PlexCond)) } }
                if (v.isNotEmpty()) op("+")
                Box(Modifier.clip(RoundedCornerShape(12.dp)).drawBehind { drawRoundRect(AMBER_RING, size = size, cornerRadius = CornerRadius(12.dp.toPx()), style = Stroke(2.dp.toPx())) }.padding(horizontal = 14.dp, vertical = 7.dp)) {
                    Text("?", style = ui(20f, 600, MUTED).copy(fontFamily = PlexCond)) }
            }
            "wall", "brick" -> {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { slot(0, "L", Modifier.weight(1f)); op("×"); slot(1, "H", Modifier.weight(1f)) }
                if (c.tool == "wall") Text(tr("qc.open"), style = ui(12f, 400, MUTED))
                if (c.tool == "wall" || c.brickOpening) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { slot(2, "ow", Modifier.weight(1f)); op("×"); slot(3, "oh", Modifier.weight(1f)) }
                if (c.tool == "brick") Row(Modifier.clip(RoundedCornerShape(10.dp)).clickable {
                    c.brickOpening = !c.brickOpening; if (!c.brickOpening) while (v.size > 2) v.removeAt(v.lastIndex); c.act = null
                }.padding(vertical = 6.dp, horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    MIcon(if (c.brickOpening) "x" else "plus", MUTED, 14.dp, 2.4f); Text(tr(if (c.brickOpening) "qb.openDel" else "qb.openAdd"), style = ui(13f, 500, MUTED))
                }
            }
            else -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CALC_SLOTS.getValue(c.tool).forEachIndexed { i, lab -> if (i > 0) op("×"); slot(i, lab, Modifier.weight(1f)) }
            }
        }
        // the result
        var err: String? = null; var txt: String? = null; var sub: Pair<String, String>? = null
        val m2 = tr("u.m2")
        when (c.tool) {
            "area" -> if (g(0) != null && g(1) != null) txt = fmtArea(g(0)!!.toLong() * g(1)!!, en) + " " + m2
            "wall" -> if (g(0) != null && g(1) != null) { val op = if (g(2) != null && g(3) != null) g(2)!!.toLong() * g(3)!! else 0L; val net = g(0)!!.toLong() * g(1)!! - op
                if (net > 0) txt = fmtArea(net, en) + " " + m2 else err = tr("qc.opBig") }
            "vol" -> if (g(0) != null && g(1) != null && g(2) != null) txt = "%.2f".format(java.util.Locale.ROOT, g(0)!!.toDouble() * g(1)!! * g(2)!! / 1e9).replace('.', if (en) '.' else ',') + " " + tr("u.m") + "³"
            "sum" -> if (v.isNotEmpty()) txt = fmtLen(v.sumOf { it!!.second }, u, en) + " " + m
            "brick" -> if (g(0) != null && g(1) != null) {
                val op = if (c.brickOpening && g(2) != null && g(3) != null) g(2)!!.toLong() * g(3)!! else 0L; val net = g(0)!!.toLong() * g(1)!! - op
                if (net <= 0) err = tr("qc.opBig") else { val (b, mo) = brickCount(net.toDouble(), app.settings.brick)
                    txt = b.toString().replace(Regex("\\B(?=(\\d{3})+(?!\\d))"), if (en) "," else " ") + " " + tr("u.pcs")
                    sub = (tr("qb.mortar") + " " + "%.2f".format(java.util.Locale.ROOT, mo).replace('.', if (en) '.' else ',') + " " + tr("u.m") + "³") to (fmtArea(net, en) + " " + m2) }
            }
            "sheet" -> if (g(0) != null && g(1) != null) {
                // the workshop's sheet size (Profile → Ustaxona sozlamalari)
                val a = g(0)!!.toLong() * g(1)!!; val ws = app.settings.workshop
                txt = uz.metrx.app.core.sheetsFor(a.toDouble(), ws.sheetL, ws.sheetW).toString() + " " + tr("u.sheet")
                sub = tr("qs.spec", "l" to ws.sheetL, "w" to ws.sheetW) to (fmtArea(a, en) + " " + m2)
            }
        }
        Row(Modifier.fillMaxWidth().drawBehind { drawLine(Color.White.copy(alpha = .12f), Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx()) }.padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr(mapOf("area" to "qc.rArea", "wall" to "qc.rWall", "vol" to "qc.rVol", "sum" to "qc.rSum", "brick" to "qc.rBrick", "sheet" to "qc.rSheet").getValue(c.tool)), style = ui(13f, 400, MUTED))
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                if (err != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { MIcon("alert", Color(0xFFFFB4A8), 16.dp, 2f); Text(err, style = ui(13f, 600, Color(0xFFFFB4A8))) }
                // a long result (bricks, a big sum in cm) gets smaller rather than cut off
                else Text(txt ?: "—", style = ui(if ((txt?.length ?: 0) > 10) 22f else 30f, 700, if (txt != null) Color.White else MUTED, 1f).copy(fontFamily = PlexCond), maxLines = 1,
                    softWrap = false, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            }
            Text(tr("qc.clear"), style = ui(13f, 400, MUTED), modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable { v.clear(); c.act = null }.padding(horizontal = 4.dp, vertical = 12.dp))
        }
        if (c.tool == "sheet") sub?.let { (a, z) -> Row(Modifier.fillMaxWidth()) { Text(a, style = ui(12.5f, 400, MUTED), modifier = Modifier.weight(1f)); Text(z, style = ui(12.5f, 400, MUTED)) } }
        if (c.tool == "brick") {
            val b = app.settings.brick
            sub?.let { (a, z) -> Row(Modifier.fillMaxWidth()) { Text(a, style = ui(12.5f, 400, MUTED), modifier = Modifier.weight(1f)); Text(z, style = ui(12.5f, 400, MUTED)) } }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("qb.spec", "l" to b.l, "w" to b.w, "h" to b.h, "j" to b.j, "s" to b.s), style = ui(12.5f, 400, MUTED), modifier = Modifier.weight(1f))
                Text(tr("qb.change"), style = ui(13f, 700, Color.White), modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable { app.sheet = Sheet.BrickSet }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FlowRow2(content: @Composable () -> Unit) = FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp), itemVerticalAlignment = Alignment.CenterVertically) { content() }

/** The latest readings as chips: a tap puts one into the calculator (prototype .qm-chips). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Chips(rs: List<Reading>, c: MeasureCalc, u: LenUnit, en: Boolean) {
    val used = c.vals.getValue(c.tool).mapNotNull { it?.first }.toSet()
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        rs.take(12).forEach { x ->
            val inUse = x.id in used
            Box(Modifier.height(44.dp).clip(RoundedCornerShape(12.dp)).background(if (inUse) G.cobalt.copy(alpha = .14f) else G.idle(.55f))
                .border(1.dp, if (inUse) G.cobalt.copy(alpha = .4f) else G.idleRim, RoundedCornerShape(12.dp)).clickable(role = Role.Button) { c.fill(x) }.padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center) { Text(fmtLen(x.mm, u, en, full = true), style = ui(15f, 600, if (inUse) G.cobalt2 else G.ink).copy(fontFamily = PlexCond)) }
        }
    }
}

@Composable
private fun ReadingList(rs: List<Reading>, u: LenUnit, en: Boolean, m: String) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f))) {
        rs.forEachIndexed { i, x ->
            if (i > 0) uz.metrx.app.ui.components.Hairline()
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(start = 14.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(fmtLen(x.mm, u, en, full = true) + " " + m, style = ui(20f, 600).copy(fontFamily = PlexCond))
                    Text(tr("qm.reading", "n" to x.n) + ", " + fmtTime(x.ts) + (x.used?.let { ", → $it" } ?: ""), style = ui(12.5f, 400, G.ink2))
                }
                if (x.src == "manual") Text(tr("src.manual"), style = ui(12.5f, 400, G.ink2))
                Box(Modifier.size(44.dp).clip(CircleShape).pressable({ app.sheet = Sheet.SendReading(x.id) }, .95f, label = tr("qm.send")), contentAlignment = Alignment.Center) { MIcon("send", G.cobalt, 18.dp, 2f) }
                Box(Modifier.size(44.dp).clip(CircleShape).pressable({ app.settings.deleteReading(x.id); app.say("qm.del") }, .95f, label = tr("common.delete")), contentAlignment = Alignment.Center) { MIcon("trash", G.ink2, 18.dp, 2f) }
            }
        }
    }
}

/** The pictures taken here (prototype camStrip): each with its first measured line, opens in the photo editor. */
@Composable
private fun Shots(ss: List<uz.metrx.app.data.Item>, u: LenUnit, en: Boolean, m: String) {
    val app = LocalApp.current
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().padding(horizontal = 2.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        Text(tr("cm.shots"), style = ui(15f, 600))
        Text(ss.size.toString(), style = ui(12f, 600, G.ink2).copy(fontFamily = PlexCond), modifier = Modifier.clip(RoundedCornerShape(50)).background(G.ink.copy(alpha = .06f)).padding(horizontal = 8.dp, vertical = 3.dp))
    }
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ss.forEach { it ->
            val v = it.els.firstOrNull { e -> e.t == "dim" && e.v != null }?.v
            Column(Modifier.width(112.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).clickable { app.push(Route.Markup(null, it.id)) }.padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                uz.metrx.app.ui.markup.MarkThumb(it, Modifier.fillMaxWidth().height(78.dp).background(Color(0xFF0E1C36)), slice = true)
                if (v != null) Text(fmtLen(v, u, en) + " " + m, style = ui(15f, 600, G.ink, 1.15f).copy(fontFamily = PlexCond), maxLines = 1, modifier = Modifier.padding(start = 10.dp, end = 10.dp, top = 6.dp))
                else Text(tr("cm.noVal"), style = ui(12.5f, 500, G.ink3, 1.3f), maxLines = 1, modifier = Modifier.padding(start = 10.dp, end = 10.dp, top = 6.dp))
                Text(uz.metrx.app.data.dn(it.name, lang), style = ui(12f, 400, G.ink2), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 10.dp))
            }
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun MeasureSheet(s: Sheet): Boolean {
    when (s) {
        Sheet.QmManual -> ManualSheet()
        Sheet.BrickSet -> BrickSheet()
        is Sheet.SendReading -> SendSheet(s)
        Sheet.LcManual -> uz.metrx.app.ui.markup.LcManualSheet()
        else -> return false
    }
    return true
}

/** Typing a distance (prototype SHEETS.qmManual). */
@Composable
private fun ManualSheet() {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    var v by rememberSaveable { mutableStateOf("") }
    var tried by remember { mutableStateOf(false) }
    val r = lenErr(v, 100_000, app.settings.unit, en)
    val focus = remember { androidx.compose.ui.focus.FocusRequester() }
    LaunchedEffect(Unit) { delay(300); runCatching { focus.requestFocus() } }
    fun save() {
        if (r !is Parsed.Ok) { tried = true; return }
        val x = app.settings.addReading(r.value.toInt(), "manual"); app.calc.fill(x); app.sheet = null; app.say("qm.saved")
    }
    GlassSheet(tr("meas.manualTitle"), { app.sheet = null }, footer = { GBtn(tr("common.save"), { save() }) }) {
        NumField(tr("qc.dist"), v, { v = it }, app.unitName(), errText(r), tried, imeAction = androidx.compose.ui.text.input.ImeAction.Done, onIme = { save() }, focusRequester = focus)
    }
}

/** Brick size, joint and spare (prototype SHEETS.qbSet). */
@Composable
private fun BrickSheet() {
    val app = LocalApp.current
    val b0 = app.settings.brick
    val f = remember { mutableStateListOf(b0.l.toString(), b0.w.toString(), b0.h.toString(), b0.j.toString(), b0.s.toString()) }
    var tried by remember { mutableStateOf(false) }
    val keys = listOf("l", "w", "h", "j", "s")
    fun err(i: Int): String? { val rg = BRICK_LIMITS.getValue(keys[i]); val n = f[i].trim().toIntOrNull(); return if (n != null && n in rg && f[i].trim().all { it.isDigit() }) null else app.t("qb.errRange", "a" to rg.first, "b" to rg.last) }
    GlassSheet(tr("qb.title"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if ((0..4).any { err(it) != null }) { tried = true; return@GBtn }
            val n = f.map { it.trim().toInt() }; app.settings.setBrickSpec(BrickSpec(n[0], n[1], n[2], n[3], n[4])); app.sheet = null
        })
    }) {
        Text(tr("qb.size"), style = ui(15f, 700))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BRICK_PRESETS.forEach { (l, w, h) ->
                val on = f[0] == "$l" && f[1] == "$w" && f[2] == "$h"
                Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.cobalt else G.idle(.6f)).border(1.dp, if (on) G.cobalt else G.idleRim, RoundedCornerShape(12.dp))
                    .clickable { f[0] = "$l"; f[1] = "$w"; f[2] = "$h" }.padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
                    Text("$l×$w×$h", style = ui(14f, 600, if (on) Color.White else G.ink).copy(fontFamily = PlexCond))
                }
            }
        }
        val mm = tr("qb.mm")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("qb.len", "qb.wid", "qb.hei").forEachIndexed { i, k -> NumField(tr(k), f[i], { f[i] = it }, mm, err(i), tried, modifier = Modifier.weight(1f)) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            NumField(tr("qb.joint"), f[3], { f[3] = it }, mm, err(3), tried, modifier = Modifier.weight(1f))
            NumField(tr("qb.spare"), f[4], { f[4] = it }, "%", err(4), tried, modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 18.dp, 2f); Text(tr("qb.note"), style = ui(13f, 400, G.ink2, 1.45f), modifier = Modifier.weight(1f)) }
    }
}

/** Sending a reading to a room's wall or height (prototype SHEETS.sendReading): it waits there for confirmation. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SendSheet(s: Sheet.SendReading) {
    val app = LocalApp.current
    val lang = LocalLang.current; val en = lang == Lang.EN
    val x = app.settings.readings.firstOrNull { it.id == s.id } ?: run { app.sheet = null; return }
    val rooms = app.store.projects.flatMap { p -> p.rooms.map { p to it } }
    GlassSheet(tr("qm.sendTitle"), { app.sheet = null }) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(fmtLen(x.mm, app.settings.unit, en, full = true), style = ui(34f, 600).copy(fontFamily = PlexCond)); Text(" " + app.unitName(), style = ui(18f, 500, G.ink2))
        }
        if (rooms.isEmpty()) Text(tr("qm.noRooms"), style = ui(14f, 400, G.ink2))
        rooms.forEach { (p, r) ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(dn(p.name, lang) + ": " + dn(r.name, lang), style = ui(15f, 700))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    (uz.metrx.app.geo.stepKeys(r, app.settings.angleSnap)).forEach { k ->
                        val label = if (k == "H") tr("ed.Hs") else tr("op.wall") + " " + k
                        Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(12.dp)).clickable {
                            app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { rr -> if (rr.id != r.id) rr else rr.copy(dims = rr.dims + (k to rr.dim(k).copy(pending = Pending(x.mm, x.src, "quick")))) }) }
                            app.settings.markReadingUsed(x.id, label)
                            app.sheet = null
                            // to the room, with that measurement chosen (prototype doSend); the Projects tab keeps its pages under it
                            app.tab = Tab.PROJECTS; app.push(Route.Editor(p.id, r.id))
                            app.ops.focusKey = k; app.ops.focusRoom = r.id
                            app.say("qm.sent", kind = ToastKind.INFO)
                        }.padding(horizontal = 12.dp), contentAlignment = Alignment.Center) { Text(label, style = ui(14f, 600)) }
                    }
                }
            }
        }
    }
}

