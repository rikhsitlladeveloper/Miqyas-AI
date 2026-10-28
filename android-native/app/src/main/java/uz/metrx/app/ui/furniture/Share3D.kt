package uz.metrx.app.ui.furniture

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Phone
import uz.metrx.app.core.Strings
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.furniture.FREE_ROOM
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.akUnits
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Role as Role3
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.share.C3Dim
import uz.metrx.app.share.C3Info
import uz.metrx.app.share.C3Wall
import uz.metrx.app.share.clientHtml
import uz.metrx.app.share.meshOf
import uz.metrx.app.share.usdzOf
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import java.io.File
import kotlin.math.atan2
import kotlin.math.hypot

/*
 * "Mijozga 3D yuborish" (Joylan ideas, 26 Oct 2026; the mockup's screen 3): the client's 3D files of a room with its
 * furniture, made on the phone (share/Client3D.kt) and sent from the share sheet (Telegram, WhatsApp, Bluetooth, Files);
 * no server, no account. What goes in (the price in Advanced, the sizes, the maker's phone) is the app's settings.
 */

/** The HTML page must stay about this small (the HTML falls back to lighter geometry above it). */
const val HTML_MAX = 2_000_000

/** The files of one share: their names and contents. */
class Client3DFiles(val html: String, val usdz: ByteArray, val htmlName: String, val usdzName: String)

/** The room piece [fid] is in (null: the order's room with the most furniture) and its furniture. */
internal fun shareScene(p: Project, fid: String?): Pair<Room, List<Furniture>>? {
    val built = p.furniture.filter { it.modules.isNotEmpty() }
    fun roomOfF(f: Furniture) = roomOf(p, f)
    val f = fid?.let { id -> built.firstOrNull { it.id == id } } ?: built.groupBy { it.roomId ?: (FREE_ROOM + it.id) }.maxByOrNull { it.value.size }?.value?.firstOrNull() ?: return null
    val room = roomOfF(f) ?: return null
    val fs = built.filter { it.id == f.id || (f.roomId != null && it.roomId == f.roomId) }
    return room to fs
}

/** A file name from the order's name: no spaces or awkward characters. */
private fun safeName(s: String) = s.replace(Regex("[\\s,№./\\\\:*?\"<>|—–]+"), "_").trim('_').ifEmpty { "METRX" }

/** Builds the client's files in the order's report language. */
internal fun client3D(app: App, p: Project, room: Room, fs: List<Furniture>, price: Boolean, dims: Boolean, phone: Boolean): Client3DFiles {
    val s = app.settings
    val l = Lang.of(p.reportLang)
    fun t(k: String, vararg v: Pair<String, Any?>) = Strings.t(k, l, if (v.isEmpty()) null else v.toMap())
    val en = l == Lang.EN
    val ws = s.workshop; val mats = s.mats
    val shell = buildShell(listOf(room), true, s.angleSnap)
    val H = (room.dim("H").v ?: fs.firstNotNullOfOrNull { it.free?.h } ?: 2700) / 1000.0
    val on = fs.flatMap { it.walls }.filter { it != ISLAND }.toSet()
    val roomParts = shell.parts.filter { it.role != Role3.FURN }
    fun fur(light: Boolean, boxes: Boolean) = furniture3D(fs, shell.bases, ws, matRgb(mats), emptySet(), look = matLook(mats), mats = mats, light = light,
        ceil = room.dim("H").v, decor = false, boxes = boxes).parts
    val walls = shell.bases.map { (id, b) -> C3Wall(id, b.ox, b.oz, b.nx, b.nz) }
    // walls keep their inside faces only (both files draw one side of a face, as the iPhone's)
    val inward = shell.bases.mapValues { it.value.nx to it.value.nz }
    val dimLines = if (!dims) emptyList() else buildList {
        on.forEach { id -> shell.bases[id]?.let { b -> add(C3Dim(b.at(0.0, H - .06, .03), b.at(b.len, H - .06, .03), fmtLen((b.len * 1000).toInt(), LenUnit.M, en) + " " + t("u.m"))) } }
        on.firstOrNull()?.let { id -> shell.bases[id]?.let { b -> add(C3Dim(b.at(.06, 0.0, .03), b.at(.06, H, .03), fmtLen((H * 1000).toInt(), LenUnit.M, en) + " " + t("u.m"))) } }
    }
    var nx = 0.0; var nz = 0.0
    on.forEach { id -> shell.bases[id]?.let { nx += it.nx; nz += it.nz } }
    if (hypot(nx, nz) < .1) { nx = 0.0; nz = 1.0 }
    val az = atan2(nx, nz) + if (on.size == 1) .38 else 0.0
    val units = akUnits(fs.filter { it.kind == "kitchen" }) + fs.filter { it.kind != "kitchen" }.sumOf { it.modules.size }
    val title = fs.joinToString(" + ") { dn(it.name, l) } + " · " + t("sh3.units", "n" to units)
    val date = uz.metrx.app.data.fmtDate(System.currentTimeMillis())
    val sub = if (uz.metrx.app.furniture.isFreeRoom(room)) date else t("sh3.room", "r" to (p.floors.firstOrNull { it.id == room.floorId }?.let { floorName(it, l) } ?: dn(room.name, l)),
        "a" to fmtLen(uz.metrx.app.geo.roomSize(room)?.first, LenUnit.M, en), "b" to fmtLen(uz.metrx.app.geo.roomSize(room)?.second, LenUnit.M, en), "d" to date)
    val priceLine = if (!price || !s.advanced) null else runCatching {
        val v = priceOf(fs, p.fprice, ws, mats, s.hws).lines.filter { ln -> fs.any { it.id == ln.key } }.fold(java.math.BigInteger.ZERO) { a, ln -> a + ln.amount }
        t("sh3.price", "v" to moneyStr(v, p.precision, en) + " " + curSuffix(p.currency, l))
    }.getOrNull()
    val ph = Phone.format(s.builderPhone).takeIf { phone && it.isNotBlank() }
    val info = C3Info(dn(p.name, l), title, sub, priceLine, s.builderName.ifBlank { "—" }, ph, dimLines, walls, t("sh3.hint"), t("sh3.noGl"), t("sh3.master", "n" to s.builderName.ifBlank { "—" }), az, l.code)
    // the page with the shaped details, lighter ones if it would be too big, plain boxes at the last
    var html = ""
    for ((light, boxes) in listOf(false to false, true to false, true to true)) {
        html = clientHtml(meshOf(roomParts + fur(light, boxes), inward), info)
        if (html.toByteArray().size <= HTML_MAX) break
    }
    // Quick Look shows the piece on its own: the floor and the walls it stands on
    val usdzMesh = meshOf(roomParts.filter { it.role == Role3.FLOOR || it.wall in on } + fur(true, false), inward)
    val base = safeName(dn(p.name, l))
    return Client3DFiles(html, usdzOf(usdzMesh, dn(p.name, l)), base + "_3D.html", base + "_3D.usdz")
}

/** Writes the chosen files to the share cache and opens the phone's share sheet. */
private fun send(ctx: Context, f: Client3DFiles, usdz: Boolean, html: Boolean, title: String) {
    val dir = File(ctx.cacheDir, "share").apply { mkdirs(); listFiles()?.forEach { if (it.name.endsWith(".html") || it.name.endsWith(".usdz")) it.delete() } }
    val uris = ArrayList<Uri>()
    if (usdz) File(dir, f.usdzName).also { it.writeBytes(f.usdz) }.let { uris += FileProvider.getUriForFile(ctx, ctx.packageName + ".files", it) }
    if (html) File(dir, f.htmlName).also { it.writeText(f.html, Charsets.UTF_8) }.let { uris += FileProvider.getUriForFile(ctx, ctx.packageName + ".files", it) }
    if (uris.isEmpty()) return
    val send = if (uris.size == 1) Intent(Intent.ACTION_SEND).apply { type = if (usdz) "model/vnd.usdz+zip" else "text/html"; putExtra(Intent.EXTRA_STREAM, uris[0]) }
        else Intent(Intent.ACTION_SEND_MULTIPLE).apply { type = "*/*"; putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris) }
    send.putExtra(Intent.EXTRA_SUBJECT, title)
    send.clipData = ClipData.newUri(ctx.contentResolver, title, uris[0]).also { c -> uris.drop(1).forEach { c.addItem(ClipData.Item(it)) } }
    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    ctx.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

private fun mb(n: Int, en: Boolean) = String.format(java.util.Locale.ROOT, "%.1f", n / 1_000_000.0).let { if (en) it else it.replace('.', ',') } + " MB"

@Composable
fun Share3DSheet(s: Sheet.Share3D) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val ctx = LocalContext.current
    val st = app.settings
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val scene = remember(p.furniture, p.rooms, s.fid) { shareScene(p, s.fid) }
    var usdzOn by rememberSaveable { mutableStateOf(true) }
    var htmlOn by rememberSaveable { mutableStateOf(true) }
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    val priceOn = st.share3dPrice && st.advanced
    val files by produceState<Client3DFiles?>(null, scene, priceOn, st.share3dDims, st.share3dPhone, st.builderName, st.builderPhone) {
        value = null
        val sc = scene ?: return@produceState
        value = withContext(Dispatchers.Default) { runCatching { client3D(app, p, sc.first, sc.second, priceOn, st.share3dDims, st.share3dPhone) }.getOrNull() }
    }
    GlassSheet(tr("sh3.title"), { app.sheet = null }) {
        if (scene == null) { Text(tr("sh3.none"), style = ui(14.5f, 500, G.ink2, 1.45f)); return@GlassSheet }
        Text(scene.second.joinToString(", ") { dn(it.name, lang) } + " — " + tr("sh3.sub"), style = ui(13f, 400, G.ink2, 1.4f))
        val f = files
        FileRow("USDZ", Brush.linearGradient(listOf(Color(0xFF5B7BFF), Color(0xFF3550E0))), f?.usdzName ?: tr("sh3.usdz"), tr("sh3.usdzS") + (f?.let { " · " + mb(it.usdz.size, en) } ?: ""), usdzOn) { usdzOn = !usdzOn }
        FileRow("HTML", Brush.linearGradient(listOf(Color(0xFF22B8A6), Color(0xFF138A7E))), f?.htmlName ?: tr("sh3.html"), tr("sh3.htmlS") + (f?.let { " · " + mb(it.html.toByteArray().size, en) } ?: ""), htmlOn) { htmlOn = !htmlOn }
        if (st.advanced) Toggle2(tr("sh3.oPrice"), tr("sh3.oPriceS"), st.share3dPrice) { st.setShare3d(price = !st.share3dPrice) }
        Toggle2(tr("sh3.oDims"), tr("sh3.oDimsS"), st.share3dDims) { st.setShare3d(dims = !st.share3dDims) }
        Toggle2(tr("sh3.oPhone"), if (st.builderPhone.isBlank()) tr("sh3.phoneNone") else tr("sh3.oPhoneS"), st.share3dPhone) { st.setShare3d(phone = !st.share3dPhone) }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.cobalt.copy(alpha = .08f)).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MIcon("send", G.cobalt2, 18.dp, 2f)
            Text(tr("sh3.note"), style = ui(12.5f, 500, G.ink, 1.4f), modifier = Modifier.weight(1f))
        }
        GBtn(if (f == null || busy) tr("sh3.making") else tr("sh3.send"), {
            if (f == null || busy) return@GBtn
            if (!usdzOn && !htmlOn) { app.say("sh3.pickOne", kind = ToastKind.INFO); return@GBtn }
            busy = true
            scope.launch {
                runCatching { withContext(Dispatchers.IO) { send(ctx, f, usdzOn, htmlOn, dn(p.name, lang) + " · 3D") } }
                    .onFailure { app.say("sh3.fail", kind = ToastKind.ERROR) }
                busy = false
            }
        }, icon = "share", enabled = f != null && (usdzOn || htmlOn))
    }
}

@Composable
private fun FileRow(badge: String, bg: Brush, name: String, sub: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().clip(shape).background(G.ink.copy(alpha = .035f)).border(1.dp, if (on) G.cobalt.copy(alpha = .45f) else G.rim, shape)
        .clickable(role = Role.Checkbox, onClick = onClick).padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(bg), contentAlignment = Alignment.Center) { Text(badge, style = ui(9.5f, 800, Color.White)) }
        Column(Modifier.weight(1f)) {
            Text(name, style = ui(13.5f, 800), maxLines = 1)
            Text(sub, style = ui(11.5f, 400, G.ink2, 1.3f))
        }
        Box(Modifier.size(22.dp).clip(CircleShape).background(if (on) G.cobalt else Color.Transparent).border(2.dp, if (on) G.cobalt else G.ink3, CircleShape), contentAlignment = Alignment.Center) {
            if (on) MIcon("check", Color.White, 13.dp, 3f)
        }
    }
}

@Composable
private fun Toggle2(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Switch, onClick = onClick), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(14.5f, 600))
            Text(sub, style = ui(12f, 400, G.ink2))
        }
        uz.metrx.app.ui.components.GSwitch(on)
    }
}
