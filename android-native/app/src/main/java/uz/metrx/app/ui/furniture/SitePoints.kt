package uz.metrx.app.ui.furniture

import kotlin.random.Random
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.PT_TYPES
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.pointDefaults
import uz.metrx.app.data.pointProblem
import uz.metrx.app.data.pointSize
import uz.metrx.app.data.uid
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.geo.parseDec
import uz.metrx.app.geo.unitDecimals
import uz.metrx.app.geo.wallCorner
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.CountPill
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.english
import uz.metrx.app.ui.editor.errText
import uz.metrx.app.ui.editor.unitName
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.max

/*
 * Stage 1a part 2 (furniture plan section 5; design canvas screen 6): sockets, switches, water, sewer, gas pipe and
 * gas meter marked on the walls of a furniture order's rooms. Builders never see them.
 */

private val COLD = Color(0xFF2563EB)
private val HOT = Color(0xFFDC2626)
private val SEWER = Color(0xFF64748B)
private val GAS = Color(0xFFEAB308)
private val METER = Color(0xFFCA8A04)
private val PLATE_INK = Color(0xFF0E1C36)

/** The colour that tells a point's kind (with its shape: plates are square, pipes round, the meter a box). */
fun pointColor(t: String): Color = when (t) {
    "cold" -> COLD; "hot" -> HOT; "sewer" -> SEWER; "gas" -> GAS; "meter" -> METER; else -> PLATE_INK
}

/**
 * A point at [c], [k] px per mm, never smaller than [minPx] across: a socket plate with two holes, a switch plate with
 * its key, a round pipe (the sewer's ring shows its diameter), the meter's box.
 */
fun DrawScope.drawSitePoint(x: SitePoint, c: Offset, k: Float, minPx: Float, line: Float = 1.2f) {
    val (wmm, hmm) = pointSize(x)
    val w = max(minPx, wmm * k); val h = max(minPx, hmm * k)
    val tl = Offset(c.x - w / 2, c.y - h / 2)
    when (x.t) {
        "socket", "switch" -> {
            drawRect(Color.White, tl, Size(w, h)); drawRect(PLATE_INK, tl, Size(w, h), style = Stroke(line))
            if (x.t == "socket") {
                drawCircle(PLATE_INK, w * .09f, c + Offset(-w * .2f, 0f)); drawCircle(PLATE_INK, w * .09f, c + Offset(w * .2f, 0f))
            } else drawLine(PLATE_INK, c + Offset(0f, -h * .25f), c + Offset(0f, h * .25f), line * 1.4f)
        }
        "sewer" -> { drawCircle(SEWER.copy(alpha = .35f), w / 2, c); drawCircle(SEWER, w / 2, c, style = Stroke(line * 1.3f)) }
        "gas" -> { drawCircle(GAS, w / 2, c); drawCircle(PLATE_INK, w / 2, c, style = Stroke(line * .8f)) }
        "meter" -> { drawRect(METER.copy(alpha = .25f), tl, Size(w, h)); drawRect(METER, tl, Size(w, h), style = Stroke(line * 1.3f)) }
        else -> { drawCircle(pointColor(x.t), w / 2, c); drawCircle(Color.White, w / 2, c, style = Stroke(line * .8f)) }
    }
}

/** A point's symbol as a small picture (type choices, cards). */
@Composable
fun PointGlyph(t: String, size: Dp = 22.dp) {
    val (h, d, mh) = pointDefaults(t)
    Canvas(Modifier.size(size)) {
        val x = SitePoint("g", t, "A", 0, h, d, mh)
        val (wmm, hmm) = pointSize(x)
        val k = this.size.minDimension * .8f / max(wmm, hmm)
        drawSitePoint(x, center, if (t == "cold" || t == "hot" || t == "gas") this.size.minDimension * .55f / 32f else k, this.size.minDimension * .45f, 1.6f)
    }
}

/* ---------------- the wall view's list ---------------- */

/** Under a wall's drawing: its points as cards, or what to mark. */
@Composable
fun PointsSection(p: Project, r: Room, wall: String) {
    val app = LocalApp.current
    val unit = app.settings.unit; val en = app.english()
    val list = r.points.filter { it.wall == wall }.sortedBy { it.off }
    val corner = wallCorner(r, wall, app.settings.angleSnap)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("pt.title"), style = ui(15.5f, 600)); CountPill(list.size)
        Spacer(Modifier.weight(1f))
        Text("+ " + tr("pt.add"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp))
            .clickable(role = Role.Button) { app.sheet = Sheet.PointForm(p.id, r.id, wall) }.padding(horizontal = 6.dp, vertical = 10.dp))
    }
    if (list.isEmpty()) Text(tr("pt.none"), style = ui(13.5f, 400, G.ink2, 1.4f))
    else Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        list.forEach { x ->
            val bad = pointProblem(x, walls(r, app.settings.angleSnap).firstOrNull { it.id == wall }?.len, r.dim("H").v) != null
            Column(Modifier.width(152.dp).glassCard(RoundedCornerShape(18.dp), fill = G.glass(.55f)).clickable { app.sheet = Sheet.PointForm(p.id, r.id, wall, x.id) }.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    PointGlyph(x.t, 18.dp); Text(app.ops.pointName(x.t), style = ui(14f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Text(tr("wv.off", "c" to corner, "v" to fmtLen(x.off, unit, en) + " " + app.unitName()), style = ui(12.5f, 400, G.ink2))
                Text(tr("pt.hV", "v" to fmtLen(x.h, unit, en) + " " + app.unitName()), style = ui(12.5f, 400, G.ink2))
                if (x.t == "sewer") Text("Ø " + x.d, style = num(12.5f, 600, G.ink2))
                if (bad) Text(tr("room.bad"), style = ui(12.5f, 600, G.err))
            }
        }
    }
}

/* ---------------- adding and editing a point ---------------- */

@Composable
fun PointSheet(s: Sheet.PointForm) {
    val app = LocalApp.current
    val ops = app.ops
    val r = ops.room(s.pid, s.rid) ?: run { app.sheet = null; return }
    val unit = app.settings.unit; val en = app.english(); val dec = unitDecimals(unit)
    val snap = app.settings.angleSnap
    val edit = s.id?.let { id -> r.points.firstOrNull { it.id == id } }
    val ws = walls(r, snap)
    var type by rememberSaveable { mutableStateOf(edit?.t ?: "socket") }
    var wall by rememberSaveable { mutableStateOf(edit?.wall ?: s.wall) }
    val L = ws.firstOrNull { it.id == wall }?.len
    var offv by rememberSaveable { mutableStateOf(fmtField(edit?.off ?: ((L ?: 2000) / 2 / 10 * 10), unit, en)) }
    var hv by rememberSaveable { mutableStateOf(fmtField(edit?.h ?: pointDefaults(type).first, unit, en)) }
    var dv by rememberSaveable { mutableStateOf(edit?.d?.takeIf { it > 0 } ?: pointDefaults(type).second) }
    var mwv by rememberSaveable { mutableStateOf(fmtField(edit?.d?.takeIf { it > 0 } ?: 300, unit, en)) }
    var mhv by rememberSaveable { mutableStateOf(fmtField(edit?.mh?.takeIf { it > 0 } ?: 400, unit, en)) }
    var src by rememberSaveable { mutableStateOf(edit?.src ?: "manual") }
    var tried by remember { mutableStateOf(false) }
    fun pick(t: String) {
        if (t == type) return
        type = t
        if (edit == null) { hv = fmtField(pointDefaults(t).first, unit, en); dv = pointDefaults(t).second }
    }
    val po = parseDec(offv, dec); val ph = parseDec(hv, dec)
    val pmw = if (type == "meter") lenErr(mwv, 2000, unit, en) else Parsed.Ok(0)
    val pmh = if (type == "meter") lenErr(mhv, 2000, unit, en) else Parsed.Ok(0)
    val ok = po is Parsed.Ok && ph is Parsed.Ok && pmw is Parsed.Ok && pmh is Parsed.Ok
    val x = if (ok) SitePoint(edit?.id ?: uid(), type, wall, (po as Parsed.Ok).value.toInt(), (ph as Parsed.Ok).value.toInt(),
        d = when (type) { "sewer" -> dv; "meter" -> (pmw as Parsed.Ok).value.toInt(); else -> 0 },
        mh = if (type == "meter") (pmh as Parsed.Ok).value.toInt() else 0, src = src) else null
    val H = r.dim("H").v
    val prob = x?.let { pointProblem(it, L, H) }
    val probText = when (prob) {
        "pt.offBig" -> tr(prob, "v" to fmtLen(L, unit, en) + " " + app.unitName())
        "pt.hBig" -> tr(prob, "v" to fmtLen(H, unit, en) + " " + app.unitName())
        else -> null
    }
    val corner = wallCorner(r, wall, snap)
    fun save() { tried = true; if (x == null || prob != null) return; ops.savePoint(s.pid, s.rid, x, edit == null) }
    GlassSheet(if (edit != null) ops.pointName(edit.t) else tr("pt.add"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (edit != null) GBtn(tr("common.delete"), { ops.deletePoint(s.pid, s.rid, edit) }, Btn.DANGER, icon = "trash", height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            else GBtn(tr("common.cancel"), { app.sheet = null }, Btn.SECONDARY, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = ok && prob == null, height = 44.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
        }
    }) {
        Text(tr("pt.type"), style = ui(15f, 700))
        PT_TYPES.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { t ->
                    val on = t == type
                    Column(Modifier.weight(1f).heightIn(min = 68.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.6f))
                        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.idleRim, RoundedCornerShape(14.dp))
                        .semantics { selected = on }.clickable(role = Role.RadioButton) { pick(t) }.padding(horizontal = 4.dp, vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        PointGlyph(t, 20.dp)
                        Text(ops.pointName(t), style = ui(11.5f, 700, if (on) G.cobalt2 else G.ink), maxLines = 2, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("op.wall"), style = ui(15f, 700))
            Seg(ws.map { it.id to it.id }, wall, subs = ws.associate { it.id to fmtLen(it.len, unit, en) }) { wall = it }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("op.offset", "c" to corner), offv, { offv = it; src = "manual" }, app.unitName(), errText(po), tried, modifier = Modifier.weight(1f))
            NumField(tr("pt.h"), hv, { hv = it; src = "manual" }, app.unitName(), errText(ph), tried, modifier = Modifier.weight(1f))
        }
        // with the real laser, its next measurement; with no laser the radar to connect one; the debug simulator: the
        // laser's newest reading not used yet (its readings' inbox) first, and with none a made-up one ([made])
        fun fromLaser(where: String, made: () -> Int, put: (String) -> Unit) {
            if (app.laser.isReal) { app.laser.await { mm -> put(fmtField(mm, unit, en)); src = "laser" }; return }
            if (!app.laser.simOn) { app.openLaser(); return }
            val rd = app.settings.readings.lastOrNull { it.used == null && it.src != "manual" }
            if (rd != null) app.settings.markReadingUsed(rd.id, where)
            put(fmtField(rd?.mm ?: made(), unit, en)); src = "sim"
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            LaserLink(tr("pt.laserOff")) { fromLaser(app.t("pt.laserOff"), { Random.nextInt(200, max(400, (L ?: 3000) - 100)) / 10 * 10 }) { offv = it } }
            LaserLink(tr("pt.laserH")) { fromLaser(app.t("pt.laserH"), { pointDefaults(type).first + Random.nextInt(-30, 31) }) { hv = it } }
        }
        if (src == "sim" || src == "laser") Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("clock", G.amberInk, 16.dp, 2f); Text(tr("pt.fromLaser"), style = ui(13f, 500, G.amberInk))
        }
        if (type == "sewer") Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("pt.d"), style = ui(15f, 700))
            Seg(listOf("50" to "Ø 50", "110" to "Ø 110"), dv.toString()) { dv = it.toInt() }
        }
        if (type == "meter") Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            NumField(tr("pt.mw"), mwv, { mwv = it }, app.unitName(), errText(pmw), tried, modifier = Modifier.weight(1f))
            NumField(tr("pt.mh"), mhv, { mhv = it }, app.unitName(), errText(pmh), tried, modifier = Modifier.weight(1f))
        }
        Text(tr("pt.centre"), style = ui(13f, 400, G.ink2))
        if (probText != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.err, 18.dp, 2f); Text(probText, style = ui(13.5f, 500, G.err, 1.35f))
        }
    }
}

@Composable
private fun LaserLink(label: String, onClick: () -> Unit) {
    Row(Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        MIcon("laser", G.cobalt, 18.dp, 2f); Text(label, style = ui(14f, 600, G.cobalt))
    }
}

