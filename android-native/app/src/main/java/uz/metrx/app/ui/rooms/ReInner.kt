package uz.metrx.app.ui.rooms

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.geo.IWK
import uz.metrx.app.geo.IW_COL
import uz.metrx.app.geo.IW_HH
import uz.metrx.app.geo.IW_KINDS
import uz.metrx.app.geo.IW_OPW
import uz.metrx.app.geo.IW_TH
import uz.metrx.app.geo.V2
import uz.metrx.app.geo.innerFaces
import uz.metrx.app.geo.iwCopyOf
import uz.metrx.app.geo.iwMoveGap
import uz.metrx.app.geo.iwPlace
import uz.metrx.app.geo.iwRotated
import uz.metrx.app.geo.iwSides
import uz.metrx.app.geo.iwWithLen
import uz.metrx.app.geo.newPiece
import uz.metrx.app.geo.pieceGeo
import uz.metrx.app.geo.pieceH
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.furniture.OptChip
import uz.metrx.app.ui.furniture.OptNote
import uz.metrx.app.ui.furniture.OptRow
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * Inner walls in the room editor and the openings step (founder-approved mockup v3, 28 Oct 2026): the "Devor qo‘shish"
 * window of ready pieces drawn from above, the piece's live pills (its length, the gaps to the walls on each side and
 * past its ends — tap one to type, with the laser), the floating card and the slider's tools (Uzunlik, Qalinlik,
 * Balandlik, O‘tish, Shakli, 90° burish, Yuzalar, Nusxa, O‘chirish). Every change has a toast with "Ortga qaytarish".
 */

/** A piece's name ("To‘g‘ri devor", "Ustun"). */
fun App.iwName(k: String) = t("iw.k.$k")

/** "Devor E (ichki)": an inner face's letter with its tag; an outer wall's letter as it is. */
fun App.wLab(r: Room, id: String) = if (isInner(r, id)) id + " " + t("iw.tag") else id

/** "2 000 × 100 × 2 700", "2 000 + 1 200 × 100 × 2 700", "400 × 400 · kvadrat", "… · o‘tish 900 × 2 100". */
fun App.iwSize(r: Room, p: InnerWall): String {
    if (p.k == "col") return mm(p.len) + " × " + mm(p.len) + " · " + t(if (p.round) "iw.rd" else "iw.sq")
    var s = mm(p.len) + (if (p.len2 > 0 && (p.k == "L" || p.k == "T")) " + " + mm(p.len2) else "") + " × " + p.th + " × " + mm(pieceH(p, roomH(r)))
    if (p.k == "arch") s += " · " + t("iw.pass", "a" to mm(p.opW), "b" to mm(p.opH))
    return s
}

/** The window's line under a card: its standard size and what it is for. */
fun App.iwCardLine(k: String, rh: Int): String {
    val D = IWK.getValue(k)
    return when (k) {
        "col" -> mm(D.len) + " × " + mm(D.len) + " · " + t("iw.d.col")
        "half" -> mm(D.len) + " × 100 · h " + mm(D.h) + " · " + t("iw.d.half")
        "arch" -> mm(D.len) + " × 100 · " + t("iw.pass", "a" to mm(D.opW), "b" to mm(min(D.opH, rh - 100)))
        else -> mm(D.len) + (if (D.len2 > 0) " + " + mm(D.len2) else "") + " × 100 · " + t("iw.toCeil")
    }
}

/* ---------------- the actions ---------------- */

private fun App.iwWarn(text: String) { toast = uz.metrx.app.ui.components.ToastMsg(text, uz.metrx.app.ui.components.ToastKind.ERROR); haptic(Hap.WARN) }

fun selectPiece(app: App, s: ReSession, id: String) {
    s.sel = ReSel.Piece(id); s.arm = null
    if (s.ghostId != null && s.ghostId != id) s.ghostId = null
    if (!s.inFlow) s.strip = null
    app.haptic(Hap.TICK)
}

/** A card picked in the window: the piece in the room's middle, selected, a ghost until it is moved. */
fun App.iwPick(s: ReSession, k: String) {
    val r = s.room ?: return
    val p = iwPlace(r, k, reSnap())
    s.iwWin = false
    s.commit(this, t("iw.added", "n" to iwName(k))) { it.copy(inner = it.inner + p) }
    s.ghostId = p.id; s.sel = ReSel.Piece(p.id); s.arm = null; s.strip = null; s.cardMin = false
}

/** A change to the selected piece ([f] gives the new one; null: nothing); its items kept on its faces and walls. */
fun App.iwSet(s: ReSession, msg: String, f: (InnerWall) -> InnerWall?): Boolean {
    val id = s.selPiece?.id ?: return false
    return s.commit(this, msg) { r ->
        val p = r.inner.firstOrNull { it.id == id } ?: return@commit null
        val n = f(p) ?: return@commit null
        if (n == p) return@commit null
        clampItems(uz.metrx.app.geo.syncFaces(r.copy(inner = r.inner.map { if (it.id == id) n else it }), reSnap()))
    }
}

fun App.iwRotate(s: ReSession) {
    val r = s.room ?: return; val p = s.selPiece ?: return
    if (p.k == "col") return
    val res = iwRotated(r, p, reSnap())
    s.ghostId = null
    iwSet(s, t("iw.rot", "n" to iwName(p.k)) + if (res.str) " · " + t("iw.str") else "") { res.p }
}

fun App.iwSetLen(s: ReSession, v: Int) {
    val p = s.selPiece ?: return
    if (v == p.len) return
    iwSet(s, t(if (p.k == "col") "iw.chSize" else "iw.chLen", "n" to iwName(p.k), "a" to mm(p.len), "b" to mm(v))) { iwWithLen(it, v) }
}

fun App.iwSetTh(s: ReSession, v: Int) { val p = s.selPiece ?: return; if (p.th != v) iwSet(s, t("iw.chTh", "n" to iwName(p.k), "a" to "${p.th}", "b" to "$v")) { it.copy(th = v) } }

fun App.iwSetH(s: ReSession, v: Int) {
    val p = s.selPiece ?: return; val r = s.room ?: return
    if (v > roomH(r)) { iwWarn(t("iw.hHigh", "v" to mm(roomH(r)))); return }
    if (p.h != v) iwSet(s, t("iw.chH", "n" to iwName(p.k), "a" to mm(pieceH(p, roomH(r))), "b" to mm(v))) { it.copy(h = v) }
}

fun App.iwSetOpW(s: ReSession, v: Int) {
    val p = s.selPiece ?: return
    if (p.opW == v) return
    if (v > p.len - 200) { iwWarn(t("iw.opWide", "v" to mm(p.len - 200))); return }
    iwSet(s, t("iw.chOpW", "n" to iwName(p.k), "a" to mm(p.opW), "b" to mm(v))) { it.copy(op = uz.metrx.app.data.IwOp(v, it.opH)) }
}

fun App.iwSetOpH(s: ReSession, v: Int) {
    val p = s.selPiece ?: return; val r = s.room ?: return
    if (p.opH == v) return
    if (v > roomH(r) - 50) { iwWarn(t("iw.hHigh", "v" to mm(roomH(r)))); return }
    iwSet(s, t("iw.chOpH", "n" to iwName(p.k), "a" to mm(p.opH), "b" to mm(v))) { it.copy(op = uz.metrx.app.data.IwOp(it.opW, v)) }
}

fun App.iwRound(s: ReSession, rd: Boolean) { val p = s.selPiece ?: return; if (p.round != rd) iwSet(s, t(if (rd) "iw.toRound" else "iw.toSquare")) { it.copy(round = rd) } }

/** A gap pill typed: the piece moved so that side is [v] from its wall. */
fun App.iwGap(s: ReSession, key: String, v: Int) {
    val r = s.room ?: return; val p = s.selPiece ?: return
    val n = iwMoveGap(r, p, key, v, reSnap()) ?: return
    iwSet(s, t("iw.gapSet", "n" to iwName(p.k), "v" to mm(v))) { n }
}

fun App.iwCopy(s: ReSession) {
    val r = s.room ?: return; val p = s.selPiece ?: return
    val c = iwCopyOf(r, p, reSnap()) ?: run { iwWarn(t("iw.noCopy")); return }
    s.commit(this, t("iw.copied", "n" to iwName(p.k))) { it.copy(inner = it.inner + c) }
    s.sel = ReSel.Piece(c.id); s.ghostId = null
}

fun App.iwDel(s: ReSession) {
    val p = s.selPiece ?: return; val r = s.room ?: return
    val lost = r.openings.count { it.fk.startsWith(p.id + ":") } + r.points.count { it.fk.startsWith(p.id + ":") }
    s.commit(this, t("iw.gone", "n" to iwName(p.k)) + if (lost > 0) " · " + t("iw.goneItems", "n" to lost) else "") { rr -> clampItems(rr.copy(inner = rr.inner.filter { it.id != p.id })) }
    s.sel = null; s.strip = null; s.ghostId = null
}

/** The keypad for a piece's field (Uzunlik, Qalinlik, Balandlik, O‘tish, a gap pill); null when it is not one. */
fun App.iwKp(s: ReSession, field: String): Kp? {
    val r = s.room ?: return null; val p = s.selPiece ?: return null
    val nm = iwName(p.k)
    return when (field) {
        "iwLen" -> Kp(t(if (p.k == "col") "iw.kpSize" else "iw.kpLen", "n" to nm), p.len, if (p.k == "col") 150 else 300, 999_999) { iwSetLen(s, it) }
        "iwTh" -> Kp(t("iw.kpTh", "n" to nm), p.th, 50, 600) { iwSetTh(s, it) }
        "iwH" -> Kp(t("iw.kpH", "n" to nm), pieceH(p, roomH(r)), 300, roomH(r)) { iwSetH(s, it) }
        "iwOpW" -> Kp(t("iw.kpOpW", "n" to nm), p.opW, 500, max(500, p.len - 200)) { iwSetOpW(s, it) }
        "iwOpH" -> Kp(t("iw.kpOpH", "n" to nm), p.opH, 1000, roomH(r)) { iwSetOpH(s, it) }
        else -> {
            if (!field.startsWith("iw") || field.length != 4) return null
            val key = field.substring(2); val sd = iwSides(r, p, reSnap())[key] ?: return null
            Kp(t(if (key[0] == 'S') "iw.kpSide" else "iw.kpEnd", "n" to nm), sd.gap, 0, 99_999) { iwGap(s, key, it) }
        }
    }
}

/* ---------------- the pills ---------------- */

/** The selected piece's live pills: the gaps (blue lines, tap to type) and its length; "magnit · devorgacha" while it snaps. */
@Composable
fun BoxScope.IwPills(s: ReSession, r: Room, fit: PlanFit, p: InnerWall, u: Float) {
    val app = LocalApp.current
    val res = iwSides(r, p, app.reSnap())
    val g = pieceGeo(p, roomH(r))
    fun M(v: V2) = fit.M(Pt(v.x, v.y))
    val cob = G.cobalt
    Canvas(Modifier.fillMaxSize()) {
        res.values.forEach { x ->
            val a = M(x.a); val b = M(x.b); val l = hypot(b.x - a.x, b.y - a.y)
            if (x.gap <= 1 || l < 6 * u) return@forEach
            val ux = (b.x - a.x) / l; val uy = (b.y - a.y) / l; val q = Offset(-uy * 5 * u, ux * 5 * u)
            drawLine(cob, a, b, 1.3f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u)))
            drawLine(cob, a + q, a - q, 1.6f * u, StrokeCap.Butt); drawLine(cob, b + q, b - q, 1.6f * u, StrokeCap.Butt)
        }
    }
    res.forEach { (k, x) ->
        val a = M(x.a); val b = M(x.b)
        if (x.gap <= 1 || hypot(b.x - a.x, b.y - a.y) < 6 * u) return@forEach
        ReBubble(mm(x.gap), (a.x + b.x) / 2, (a.y + b.y) / 2, small = true, onClick = { app.openKp(s, "iw$k") })
    }
    val lp = M(if (p.k == "col") g.c else g.c + g.d * (p.len / 4.0))
    ReBubble((if (p.k == "col") "" else app.t("iw.lenShort") + " ") + mm(p.len), lp.x, lp.y, onClick = { app.openKp(s, "iwLen") })
    s.iwMag?.takeIf { it.outer.isNotEmpty() || it.pieces.isNotEmpty() }?.let {
        val mp = M(g.c + g.n * (-(p.th / 2.0 + 260)))
        ReBubble(app.t("iw.magnet"), mp.x, mp.y, live = true, small = true)
    }
}

/* ---------------- the window ---------------- */

/** A ready piece drawn from above for the window's card. */
@Composable
fun IwThumb(k: String, modifier: Modifier) {
    val ink = RP.wallc; val frm = G.ink3
    Canvas(modifier) {
        val W = size.width; val H = size.height; val u = density
        drawRoundRect(frm.copy(alpha = .5f), Offset(8 * u, 6 * u), Size(W - 16 * u, H - 12 * u), CornerRadius(4 * u), style = Stroke(1.2f * u))
        if (k == "col") {
            val s = min(W, H) * .32f
            drawRect(ink, Offset(W * .33f - s / 2, H / 2 - s / 2), Size(s, s))
            drawCircle(ink, s / 2, Offset(W * .67f, H / 2))
            return@Canvas
        }
        val p = newPiece(k, V2(0.0, 0.0), 2700, "t").copy(th = 150)
        val g = pieceGeo(p, 2700)
        val pts = g.R.flatten()
        val mnx = pts.minOf { it.x }; val mxx = pts.maxOf { it.x }; val mny = pts.minOf { it.y }; val mxy = pts.maxOf { it.y }
        val sc = min((W - 44 * u) / max(mxx - mnx, 1.0).toFloat(), (H - 30 * u) / max(mxy - mny, 1.0).toFloat())
        val ox = (W - (mxx - mnx).toFloat() * sc) / 2 - mnx.toFloat() * sc; val oy = (H - (mxy - mny).toFloat() * sc) / 2 - mny.toFloat() * sc
        fun M(v: V2) = Offset(ox + v.x.toFloat() * sc, oy + v.y.toFloat() * sc)
        g.R.forEach { q -> val pth = Path().apply { q.forEachIndexed { i, v -> val o = M(v); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }; close() }
            drawPath(pth, ink.copy(alpha = if (k == "half") .55f else 1f)) }
        g.gap?.let { (g0, g1) -> val t = p.th / 2.0
            listOf(t, -t).forEach { o -> drawLine(G.ink3, M(g0 + g.n * o), M(g1 + g.n * o), 1.4f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))) } }
    }
}

/** "Devor qo‘shish": the six ready pieces as cards over the dimmed plan; outside or "Bekor" closes it. */
@Composable
fun BoxScope.IwWindow(s: ReSession) {
    val app = LocalApp.current
    if (!s.iwWin) return
    val r = s.room ?: return
    val close = { s.iwWin = false; app.haptic(Hap.TICK) }
    Box(Modifier.fillMaxSize().background(Color(0x6B0F172A)).clickable(remember { MutableInteractionSource() }, null) { close() })
    Box(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 12.dp, vertical = 16.dp), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().widthIn(max = 460.dp).shadow(24.dp, RoundedCornerShape(28.dp)).clip(RoundedCornerShape(28.dp)).background(G.solid)
            .clickable(remember { MutableInteractionSource() }, null) {}.verticalScroll(rememberScrollState()).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(RP.wallc), contentAlignment = Alignment.Center) { ReIcon("iw", Color.White, 20.dp) }
                Column(Modifier.weight(1f)) {
                    Text(tr("iw.winT"), style = ui(16f, 800, G.ink, 1.2f))
                    Text(tr("iw.winSub"), style = ui(12f, 500, G.ink2, 1.3f))
                }
                RoundX("close", tr("common.close")) { close() }
            }
            IW_KINDS.chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { k ->
                        val shape = RoundedCornerShape(18.dp)
                        Column(Modifier.weight(1f).fillMaxHeight().clip(shape).background(chipBg).border(1.dp, G.rim, shape)
                            .semantics { contentDescription = app.iwName(k) }.clickable(role = Role.Button) { app.iwPick(s, k) }.padding(6.dp)) {
                            Box(Modifier.fillMaxWidth().height(70.dp).clip(RoundedCornerShape(13.dp)).background(RP.elev)) { IwThumb(k, Modifier.fillMaxSize()) }
                            Text(app.iwName(k), style = ui(13f, 800, G.ink, 1.2f), modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp))
                            Text(app.iwCardLine(k, roomH(r)), style = num(11f, 500, G.ink2), modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 2.dp, bottom = 2.dp))
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
            Text(tr("iw.winNote", "h" to mm(roomH(r))), style = ui(12f, 500, G.ink2, 1.35f), modifier = Modifier.padding(horizontal = 4.dp))
            Box(Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(16.dp)).background(chipBg).border(1.dp, G.rim, RoundedCornerShape(16.dp))
                .clickable(role = Role.Button) { close() }, contentAlignment = Alignment.Center) { Text(tr("common.cancel"), style = ui(13.5f, 700)) }
        }
    }
}

/** The icon row's first tile in the openings step and the editor's Qo‘shish: "Devor qo‘shish". */
@Composable
fun IwTile(s: ReSession) {
    val app = LocalApp.current
    val shape = RoundedCornerShape(16.dp)
    Column(Modifier.width(78.dp).heightIn(min = 66.dp).clip(shape).background(RP.wallc.copy(alpha = .12f)).border(1.dp, RP.wallc.copy(alpha = .5f), shape)
        .semantics { contentDescription = app.t("iw.add") }.clickable(role = Role.Button) { s.iwWin = true; s.arm = null; s.pk = null; app.haptic(Hap.TICK) }
        .padding(vertical = 6.dp, horizontal = 2.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)) {
        ReIcon("iw", RP.wallc, 24.dp)
        Text(tr("iw.add"), style = ui(10.5f, 700, G.ink, 1.1f), textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

/* ---------------- the floating card (openings step) ---------------- */

@Composable
private fun SmallChip(label: String, on: Boolean, onClick: () -> Unit) {
    Text(label, style = num(12.5f, 800, if (on) Color.White else G.ink), modifier = Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(11.dp))
        .background(if (on) G.cobalt else chipBg).border(1.dp, if (on) Color.Transparent else G.rim, RoundedCornerShape(11.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 10.dp, vertical = 8.dp))
}

/** The selected piece's card over the icon row: name and size, thickness (or a column's shape), its faces, a problem, the buttons. */
@Composable
fun PieceCard(s: ReSession, p: InnerWall, base: Modifier) {
    val app = LocalApp.current
    val r = s.room ?: return
    val nm = app.iwName(p.k) + if (s.ghostId == p.id) " · " + app.t("iw.new") else ""
    val issue = app.issuesOf(r).firstOrNull { it.id == p.id }
    val badge = @Composable { Box(Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)).background(RP.wallc), contentAlignment = Alignment.Center) { ReIcon("iw", Color.White, 19.dp) } }
    if (s.cardMin) {
        Row(base.padding(start = 8.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            badge()
            Column(Modifier.weight(1f)) {
                Text(nm, style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(app.iwSize(r, p) + " mm", style = num(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            RoundX("up", tr("re.cardOpen")) { s.cardMin = false; app.haptic(Hap.TICK) }
            RoundX("close", tr("re.desel")) { deselect(s) }
        }
        return
    }
    Column(base.padding(start = 12.dp, end = 10.dp, top = 10.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            badge()
            Column(Modifier.weight(1f)) {
                Text(nm, style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(app.iwSize(r, p) + " mm", style = num(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            RoundX("down", tr("re.cardMin")) { s.cardMin = true; app.haptic(Hap.TICK) }
            RoundX("close", tr("re.desel")) { deselect(s) }
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            if (p.k != "col") { Text(tr("iw.th"), style = ui(12f, 700, G.ink2)); IW_TH.forEach { v -> SmallChip("$v", p.th == v) { app.iwSetTh(s, v) } } }
            else { Text(tr("iw.shape"), style = ui(12f, 700, G.ink2)); SmallChip(tr("iw.square"), !p.round) { app.iwRound(s, false) }; SmallChip(tr("iw.round"), p.round) { app.iwRound(s, true) } }
            val fc = innerFaces(r, app.reSnap()).filter { it.pid == p.id }
            if (fc.isNotEmpty()) {
                Spacer(Modifier.width(6.dp)); Text(tr("iw.faces"), style = ui(12f, 700, G.ink2))
                fc.forEach { f -> SmallChip(f.id, false) { selectWall(app, s, f.id) } }
                Text(tr("iw.facesFor"), style = ui(11f, 600, G.ink3), maxLines = 1)
            }
        }
        if (issue != null) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReIcon("warn", G.amberInk, 18.dp); Text(app.issueText(issue), style = ui(12.5f, 600, G.ink, 1.3f), modifier = Modifier.weight(1f))
        }
        val btns = ArrayList<Triple<String, String, () -> Unit>>()
        btns += Triple(tr(if (p.k == "col") "iw.t.size" else "re.t.len"), "ruler") { app.openKp(s, "iwLen") }
        if (p.k == "half") btns += Triple(tr("re.t.rh"), "height") { app.openKp(s, "iwH") }
        if (p.k == "arch") btns += Triple(tr("iw.t.op"), "width") { app.openKp(s, "iwOpW") }
        if (p.k != "col") btns += Triple(tr("iw.t.rot"), "rotate") { app.iwRotate(s) }
        btns += Triple(tr("re.t.copy"), "copy") { app.iwCopy(s) }
        btns += Triple(tr("re.t.del"), "trash") { app.iwDel(s) }
        // one row of four (a small phone keeps the plan in sight), else rows of three
        val per = if (btns.size <= 4) 4 else 3
        btns.chunked(per).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { (l, ic, f) -> FcBtn(l, ic, red = ic == "trash", modifier = Modifier.weight(1f), onClick = f) }
                repeat(per - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/* ---------------- the editor's slider ---------------- */

/** A piece's tool strips: Qalinlik, Balandlik, O‘tish, Shakli, Yuzalar. */
@Composable
fun PieceOptions(s: ReSession, k: String, back: () -> Unit) {
    val app = LocalApp.current
    val r = s.room ?: return
    val p = s.selPiece ?: return
    val nm = app.iwName(p.k)
    when (k) {
        "iwTh" -> OptRow(tr("iw.th"), tr("iw.thSub", "n" to nm, "v" to p.th), back, key = k) {
            IW_TH.forEach { v -> OptChip("$v mm", p.th == v) { app.iwSetTh(s, v) } }
            OptChip(tr("re.type"), false) { app.openKp(s, "iwTh") }
        }
        "iwH" -> OptRow(tr("re.t.rh"), tr("iw.hSub", "n" to nm, "v" to mm(pieceH(p, roomH(r)))), back, key = k) {
            IW_HH.forEach { v -> OptChip(mm(v), pieceH(p, roomH(r)) == v) { app.iwSetH(s, v) } }
            OptChip(tr("re.type"), false) { app.openKp(s, "iwH") }
        }
        "iwOp" -> OptRow(tr("iw.opT"), mm(p.opW) + " × " + mm(p.opH) + " mm", back, key = k) {
            IW_OPW.forEach { v -> OptChip(mm(v), p.opW == v) { app.iwSetOpW(s, v) } }
            OptChip(tr("iw.opWk"), false) { app.openKp(s, "iwOpW") }
            OptChip(tr("iw.opHk", "v" to mm(p.opH)), false) { app.openKp(s, "iwOpH") }
        }
        "iwShape" -> OptRow(tr("iw.k.col"), app.iwSize(r, p), back, key = k) {
            OptChip(tr("iw.square"), !p.round) { app.iwRound(s, false) }
            OptChip(tr("iw.round"), p.round) { app.iwRound(s, true) }
            Box(Modifier.width(1.dp).height(34.dp).background(G.ink.copy(alpha = .1f)))
            IW_COL.forEach { v -> OptChip(mm(v), p.len == v) { app.iwSetLen(s, v) } }
        }
        "iwFace" -> OptRow(tr("iw.faces"), tr("iw.facesSub"), back, key = k) {
            innerFaces(r, app.reSnap()).filter { it.pid == p.id }.forEach { f -> OptChip(tr("re.wall", "w" to f.id), false) { selectWall(app, s, f.id) } }
        }
        else -> OptNote("")
    }
}
