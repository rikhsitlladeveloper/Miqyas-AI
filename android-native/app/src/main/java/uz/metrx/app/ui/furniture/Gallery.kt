package uz.metrx.app.ui.furniture

import kotlin.random.Random
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.furniture.FModelDef
import uz.metrx.app.furniture.GALLERY
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.bestFirst
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.resized
import uz.metrx.app.furniture.stepIssue
import uz.metrx.app.furniture.stepsOf
import uz.metrx.app.furniture.valsOf
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.parseDec
import uz.metrx.app.geo.unitDecimals
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Adding furniture (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5): one gallery of 3D cards
 * grouped by room; a model's main sizes one at a time, the size being asked shown on the piece; which room it goes into
 * (or none). In a measured room the sizes come from the room and the walls step follows ([FPlaceScreen]). The rules are
 * in furniture/Steps.kt.
 */

/* ---------------- small helpers ---------------- */

/** Step values as a route string, "s0=3000,h=2700", and back. */
internal fun encodeVals(v: Map<String, Int>) = v.entries.joinToString(",") { "${it.key}=${it.value}" }
internal fun decodeVals(s: String?): Map<String, Int> =
    s.orEmpty().split(',').mapNotNull { e -> e.split('=').takeIf { it.size == 2 }?.let { (k, v) -> v.toIntOrNull()?.let { k to it } } }.toMap()

/** The steps' typed texts by key, as one saveable string (texts may hold commas and spaces), and back. */
internal fun encodeTexts(t: Map<String, String>) = t.entries.joinToString("\u0001") { it.key + "\u0002" + it.value }
internal fun decodeTexts(s: String): Map<String, String> =
    s.split('\u0001').mapNotNull { e -> e.split('\u0002').takeIf { it.size == 2 }?.let { it[0] to it[1] } }.toMap()

/** A typed length in mm (null when empty, unreadable or zero). */
internal fun parseMm(s: String, unit: LenUnit): Int? = (parseDec(s, unitDecimals(unit)) as? Parsed.Ok)?.value?.toInt()?.takeIf { it > 0 }

@Composable
internal fun unitWord(unit: LenUnit) = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")

/** The gallery group a room's furniture belongs to: a kitchen's kitchens, a living room's, a hallway's; the others the bedroom's. */
private fun App.groupOf(p: Project, rid: String?): String? {
    val r = rid?.let { id -> p.rooms.firstOrNull { it.id == id } } ?: return null
    val w = p.floors.firstOrNull { it.id == r.floorId }
    if (w?.type == "kitchen") return "kitchen"
    val n = w?.name ?: r.name
    // the room may have been named while the app spoke another language
    fun named(key: String) = Lang.entries.any { n.startsWith(uz.metrx.app.core.Strings.t(key, it)) }
    return when {
        named("fr.living") -> "living"
        named("fr.hall") -> "hall"
        named("fr.kids") -> "kids"
        named("fr.bath") -> "bath"
        else -> "bedroom"
    }
}

/** The group's name: the room names, a hallway and a study. */
@Composable
private fun groupName(g: String) = tr(when (g) { "hall" -> "fg.hall"; "office" -> "fg.office"; else -> "fr.$g" })

/* ---------------- the cards' pictures ---------------- */

/** The gallery's pictures, made once from the app's own 3D of each model at its usual size (again when the boards change). */
object PiecePics {
    val pics = mutableStateMapOf<String, ImageBitmap>()
    private var key = 0

    suspend fun make(ws: Workshop, mats: List<Mat>, w: Int, h: Int, density: Float) {
        val k = 31 * ws.hashCode() + mats.hashCode()
        if (k != key) { pics.clear(); key = k }
        for ((_, ids) in GALLERY) for (id in ids) {
            if (pics[id] != null) continue
            val m = fModel(id) ?: continue
            val img = withContext(Dispatchers.Default) { runCatching { piecePicture(pieceScene(pieceOf(m, emptyMap(), ws, ""), ws, mats), w, h, density) }.getOrNull() }
            if (img != null) pics[id] = img
        }
    }
}

/* ---------------- the gallery ---------------- */

@Composable
fun FGalleryScreen(rt: Route.FGallery) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val first = app.groupOf(p, rt.rid)
    val groups = if (first == null) GALLERY else GALLERY.sortedBy { if (it.first == first) 0 else 1 }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val tops = remember { mutableStateMapOf<String, Int>() }
    val dens = LocalDensity.current.density
    val ws = app.settings.workshop; val mats = app.settings.mats
    LaunchedEffect(ws, mats) { PiecePics.make(ws, mats, (200 * dens).toInt(), (170 * dens).toInt(), dens) }
    // the chip of the group at the top of the page
    val cur = if (scroll.maxValue > 0 && scroll.value >= scroll.maxValue - 4) groups.last().first
        else groups.lastOrNull { (tops[it.first] ?: Int.MAX_VALUE) <= scroll.value + 60 }?.first ?: groups.first().first

    fun pick(m: FModelDef) {
        app.kit.sel = null
        if (room != null) app.push(Route.FPlace(p.id, null, room.id, m.id)) else app.push(Route.FSteps(p.id, m.id))
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        PageBar(frosted = true) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
            Spacer(Modifier.width(6.dp))
            BarTitle(tr("fg.title"), eyebrow = dn(p.name, lang))
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            groups.forEach { (g, _) ->
                val on = g == cur
                Text(groupName(g), style = ui(14f, 700, if (on) G.solid else G.ink), maxLines = 1,
                    modifier = Modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (on) G.ink else G.glass(.55f)).semantics { selected = on }
                        .clickable(role = Role.Tab) { scope.launch { scroll.animateScrollTo(tops[g] ?: 0) } }.padding(horizontal = 16.dp, vertical = 10.dp))
            }
        }
        Column(Modifier.weight(1f).verticalScroll(scroll).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (room != null) {
                val f = { mm: Int? -> fmtLen(mm, LenUnit.M, en) }
                Text(tr("fg.forRoom", "r" to (p.floors.firstOrNull { it.id == room.floorId }?.let { floorName(it, lang) } ?: dn(room.name, lang)),
                    "a" to f(room.dim("A").v), "b" to f(room.dim("B").v), "h" to f(room.dim("H").v)), style = ui(13.5f, 400, G.ink2, 1.4f))
            } else Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).dashedGlass(18.dp).clickable(role = Role.Button) { app.sheet = Sheet.FNewRoom(p.id) }
                .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon("room", G.cobalt, 24.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(tr("fg.measure"), style = ui(14.5f, 700, G.cobalt2))
                    Text(tr("fg.measureS"), style = ui(12.5f, 400, G.ink2))
                }
            }
            groups.forEach { (g, ids) ->
                Row(Modifier.padding(top = 8.dp, start = 2.dp).onGloballyPositioned { tops[g] = it.positionInParent().y.toInt() }, verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(groupName(g), style = ui(17f, 800))
                    Text("${ids.size}", style = ui(12.5f, 500, G.ink3))
                }
                ids.mapNotNull { fModel(it) }.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { m -> ModelCard(m, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { pick(m) } }
                    }
                }
            }
            if (rt.fromNew) Text(tr("fz.needL"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp)
                .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.pop() }.padding(horizontal = 16.dp, vertical = 12.dp))
        }
    }
}

@Composable
private fun ModelCard(m: FModelDef, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = tr("fz.m.${m.id}")
    val pic: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.aspectRatio(200f / 170f).clip(RoundedCornerShape(14.dp)).background(Color(0xFFF6F8FC)), contentAlignment = Alignment.Center) {
            val img = PiecePics.pics[m.id]
            if (img != null) Image(img, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) else Text("3D…", style = ui(11f, 600, G.ink3))
        }
    }
    val words: @Composable () -> Unit = {
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(name, style = ui(14.5f, 800, G.ink), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(tr("fz.s.${m.id}"), style = ui(12f, 500, G.ink2, 1.3f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
    val mod = modifier.clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = name }.padding(8.dp)
    // the last card of an odd row takes the whole width, its picture beside the words
    if (wide) Row(mod, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        pic(Modifier.weight(1f)); Box(Modifier.weight(1f)) { words() }
    } else Column(mod, verticalArrangement = Arrangement.spacedBy(6.dp)) { pic(Modifier.fillMaxWidth()); words() }
}

/* ---------------- the sizes, one at a time ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun FStepsScreen(rt: Route.FSteps) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val m = fModel(rt.model) ?: return
    val edit = rt.fid?.let { id -> p.furniture.firstOrNull { it.id == id } }
    val ws = app.settings.workshop; val mats = app.settings.mats
    val unit = app.settings.unit
    val had = rt.vals?.let { decodeVals(it) } ?: edit?.let { valsOf(it, ws) } ?: emptyMap()
    // what was typed, by step key; a choice step keeps the index of what was chosen ("" the usual one)
    var textsS by rememberSaveable(rt) { mutableStateOf(encodeTexts(stepsOf(m, had).let { st ->
        had.mapValues { (k, v) -> if (st.any { it.key == k && it.choice }) "$v" else fmtField(v, unit, en) } })) }
    val texts = decodeTexts(textsS)
    // a corner piece's side steps follow which sides were measured; its shape is chosen once, when it is made
    val steps = stepsOf(m, texts["ms"]?.toIntOrNull()?.let { mapOf("ms" to it) } ?: emptyMap()).filter { edit == null || it.key != "sh" }
    val n = steps.size
    fun txt(i: Int) = texts[steps[i].key] ?: ""
    fun setTxt(i: Int, v: String) { textsS = encodeTexts(texts + (steps[i].key to v)) }
    // 0 … n-1 a size, n the summary; back: the step was opened from the summary, was: its text then
    var at by rememberSaveable(rt) { mutableIntStateOf(if (rt.vals != null) n else 0) }
    var back by rememberSaveable(rt) { mutableStateOf(false) }
    var was by rememberSaveable(rt) { mutableStateOf("") }
    var laser by remember { mutableStateOf<String?>(null) }   // "busy", or the reading's words
    val scope = rememberCoroutineScope()
    // only sizes within their range reach the piece: a typed 99999 would otherwise build a 100 m kitchen on every key
    fun typed(i: Int): Int? = if (steps[i].choice) txt(i).toIntOrNull() else parseMm(txt(i), unit)
    val vals = steps.indices.mapNotNull { i -> typed(i)?.takeIf { stepIssue(steps[i], it) == null }?.let { steps[i].key to it } }.toMap()
    val piece = remember(vals, ws) { if (edit != null) resized(edit, vals, ws) else pieceOf(m, vals, ws, "") }
    val scene = remember(piece, mats) { pieceScene(piece, ws, mats) }
    val uw = unitWord(unit)
    fun issueOf(i: Int): String? {
        if (steps[i].choice) return null
        // 0 or a wrong number says so (Next stays off without a word otherwise)
        val mm = parseMm(txt(i), unit) ?: return if (txt(i).isBlank()) null else app.t(if (txt(i).trim().trimStart('0', ',', '.').isEmpty()) "err.zero" else "tl.sizeErr")
        return stepIssue(steps[i], mm)?.let { (k, v) -> app.t(k, "v" to fmtLen(v, unit, en) + " " + app.t(if (unit == LenUnit.CM) "u.cm" else "u.m")) }
    }
    fun ok(i: Int) = steps[i].choice || (parseMm(txt(i), unit) != null && issueOf(i) == null)
    // the sides worked out from the ones typed (a corner piece), and whether one comes out of what the piece can be
    val derived = uz.metrx.app.furniture.derivedSides(m, vals)
    fun next() {
        if (at >= n || !ok(at)) return
        laser = null
        if (back) { back = false; at = n } else at += 1
    }
    // after a laser reading [v] went into step [i]: on to the next step when it fits (read from [v]: this page's texts are
    // the ones it was drawn with, older than the reading)
    fun nextAfter(i: Int, v: String) {
        val mm = parseMm(v, unit) ?: return
        if (at != i || stepIssue(steps[i], mm) != null) return
        laser = null
        if (back) { back = false; at = n } else at = i + 1
    }
    fun prev() {
        laser = null
        when {
            // back to the summary: a size left empty or wrong gets its old value again
            at < n && back -> { if (!ok(at)) setTxt(at, was); back = false; at = n }
            at > 0 -> at -= 1
            else -> app.pop()
        }
    }
    BackHandler { prev() }

    // a real laser's measurement goes into the size being asked, then on to the next step when it fits
    fun gotReal(mm: Int): Boolean {
        if (at >= n || steps[at].choice) return false
        val i = at
        val tv = fmtField(mm, unit, en)
        setTxt(i, tv)
        laser = app.t("fx.got", "v" to fmtLen(mm, unit, en) + " " + app.t(if (unit == LenUnit.CM) "u.cm" else "u.m"))
        scope.launch { delay(900); nextAfter(i, tv) }
        return true
    }
    uz.metrx.app.laser.LaserSink { mm -> gotReal(mm) }

    // with the real laser, its next measurement; else the laser's newest reading not used yet (its readings' inbox)
    // first, and with none a made-up one near the usual size (the simulator, as the editor's laser button)
    fun reading() {
        if (laser == "busy" || at >= n || steps[at].choice) return
        if (app.laser.isReal) {
            app.laser.await(onCancel = { if (laser == "busy") laser = null }) { mm -> laser = null; if (!gotReal(mm)) app.settings.addReading(mm, "laser") }
            laser = "busy"
            return
        }
        val s = steps[at]; val i = at
        val r = app.settings.readings.lastOrNull { it.used == null && it.src != "manual" }
        if (r != null) {
            app.settings.markReadingUsed(r.id, app.t(s.label))
            val tv = fmtField(r.mm, unit, en)
            setTxt(i, tv)
            laser = app.t("fx.got", "v" to fmtLen(r.mm, unit, en) + " " + app.t(if (unit == LenUnit.CM) "u.cm" else "u.m"))
            scope.launch { delay(900); nextAfter(i, tv) }
            return
        }
        scope.launch {
            laser = "busy"
            delay(900)
            val v = ((s.usual + Random.nextInt(-120, 121)) / 5) * 5
            val tv = fmtField(v, unit, en)
            setTxt(i, tv)
            laser = app.t("fx.got", "v" to fmtLen(v, unit, en) + " " + app.t(if (unit == LenUnit.CM) "u.cm" else "u.m"))
            delay(900)
            nextAfter(i, tv)
        }
    }

    fun finish() {
        if (!app.once()) return
        if (edit != null) {
            val g = resized(edit, vals, ws)
            app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == edit.id) g else it }) }
            app.kit.forget(edit.id); app.kit.tick++; app.pop(); app.say("fz.saved")
        } else {
            // the sizes stay with this page, so coming back from "Which room?" finds them
            app.setTop(rt.copy(vals = encodeVals(vals)))
            app.push(Route.FWhere(p.id, m.id, encodeVals(vals)))
        }
    }

    val imeOn = WindowInsets.isImeVisible
    val footer: @Composable (Modifier) -> Unit = { mm ->
        FloatingFooter(mm) {
            if (at < n) GBtn(tr("common.next"), ::next, enabled = ok(at))
            else GBtn(tr(if (edit != null) "common.save" else "fr.continue"), ::finish, enabled = steps.indices.all { ok(it) } && derived.none { it.third })
        }
    }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), ::prev, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("fz.m.${m.id}"), eyebrow = if (at < n) tr("fx.step", "i" to at + 1, "n" to n) else tr(if (edit != null) "fz.editSizes" else "fx.sumT"))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (imeOn) 16.dp else 120.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // where we are: a dot a size, the last one the summary
                Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0..n).forEach { i ->
                        Box(Modifier.size(if (i == at) 22.dp else 8.dp, 8.dp).clip(CircleShape).background(when { i == at -> G.cobalt; i < at -> G.cobalt.copy(alpha = .45f); else -> G.ink.copy(alpha = .15f) }))
                    }
                }
                val hi = if (at < n && !steps[at].choice) steps[at].key else null
                val label = if (hi != null) parseMm(txt(at), unit)?.let { fmtLen(it, unit, en) + " " + uw } ?: "?" else null
                // with the keyboard up the picture gets lower, so the field and the laser stay in sight
                Box(Modifier.fillMaxWidth().aspectRatio(if (imeOn && at < n) 2.1f else 1f / .92f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    PieceView(scene, hi, label, Modifier.fillMaxSize())
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                if (at < n && steps[at].pics) PicsAsk(m, steps[at], txt(at).toIntOrNull() ?: steps[at].usual, texts["sh"]?.toIntOrNull() ?: had["sh"] ?: 0) { v -> setTxt(at, "$v") }
                else if (at < n && steps[at].choice) ChoiceAsk(steps[at], txt(at).toIntOrNull() ?: steps[at].usual) { v -> setTxt(at, "$v") }
                else if (at < n) StepAsk(steps[at], txt(at), { v -> setTxt(at, v); laser = null }, issueOf(at), uw, at, ::next, laser, ::reading)
                else Summary(steps, steps.indices.map { i ->
                    val s = steps[i]
                    if (s.choice) app.t(s.opts.getOrElse(txt(i).toIntOrNull() ?: s.usual) { s.opts[0] }) else (parseMm(txt(i), unit)?.let { fmtLen(it, unit, en) } ?: txt(i)) + " " + uw
                }, derived.map { (k, v, bad) -> Triple(app.t(k), fmtLen(v, unit, en) + " " + uw, bad) }, when {
                    // a piece of several boxes is built again from its sizes: what was changed box by box goes (said before saving)
                    edit != null && (edit.type in uz.metrx.app.furniture.PIECE_TYPES || edit.type == "loft") -> "fx.noteRebuild"
                    m.kind == "kitchen" -> "fx.noteK"; m.type in uz.metrx.app.furniture.ITEM_TYPES -> "fx.noteI"; else -> "fx.noteW" }) { i -> was = txt(i); back = true; at = i }
            }
            if (imeOn) footer(Modifier)
        }
        if (!imeOn) footer(Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun StepAsk(s: uz.metrx.app.furniture.SizeStep, text: String, onText: (String) -> Unit, issue: String?, uw: String, at: Int, onNext: () -> Unit,
                    laser: String?, onRead: () -> Unit) {
    val app = LocalApp.current
    val en = app.settings.lang == Lang.EN
    val fr = remember { FocusRequester() }
    LaunchedEffect(at) { runCatching { fr.requestFocus() } }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr(s.label), style = ui(21f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        Text(tr(s.help), style = ui(13f, 400, G.ink2, 1.4f))
        val bad = issue != null
        val shape = RoundedCornerShape(18.dp)
        Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(shape).background(G.glass(.85f)).border(2.dp, if (bad) G.err else G.cobalt, shape).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) {
                if (text.isEmpty()) Text(fmtField(s.usual, app.settings.unit, en), style = num(24f, 600, Color(0xFFA7B0C0)))
                BasicTextField(text, { v -> onText(v.filter { it.isDigit() || it == ',' || it == '.' || it == ' ' }.take(8)) }, Modifier.fillMaxWidth().focusRequester(fr)
                    .semantics { contentDescription = app.t(s.label) }, textStyle = num(24f, 700, G.ink), singleLine = true, cursorBrush = SolidColor(G.cobalt),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Next), keyboardActions = KeyboardActions(onNext = { onNext() }))
            }
            Text(uw, style = ui(15f, 700, G.ink3))
            // the laser's button sits in the field, so it stays in sight above the keyboard
            if (app.settings.laser == Laser.CONNECTED) GBtn(tr("fx.laser"), onRead, icon = "laser", enabled = laser != "busy", height = 44.dp, corner = 14.dp, fontSize = 13.5f, fill = false)
        }
        if (issue != null) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { MIcon("alert", G.err, 18.dp, 2f); Text(issue, style = ui(13.5f, 500, G.err)) }
        // the usual sizes (a mattress's) a tap away
        if (s.picks.isNotEmpty()) Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            s.picks.forEach { v -> Chip(fmtLen(v, app.settings.unit, en), parseMm(text, app.settings.unit) == v) { onText(fmtField(v, app.settings.unit, en)) } }
        }
        LaserLine(app, laser)
    }
}

/** A choice on its own step (a bed's kind, a table's legs): one card an option, the chosen one marked. */
@Composable
private fun ChoiceAsk(s: uz.metrx.app.furniture.SizeStep, cur: Int, onPick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr(s.label), style = ui(21f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        Text(tr(s.help), style = ui(13f, 400, G.ink2, 1.4f))
        s.opts.forEachIndexed { i, k ->
            val on = i == cur
            val shape = RoundedCornerShape(16.dp)
            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
                .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape).semantics { selected = on }
                .clickable(role = Role.RadioButton) { onPick(i) }.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(20.dp).clip(CircleShape).border(2.dp, if (on) G.cobalt else G.ink3, CircleShape), contentAlignment = Alignment.Center) {
                    if (on) Box(Modifier.size(10.dp).clip(CircleShape).background(G.cobalt))
                }
                Column(Modifier.weight(1f)) {
                    Text(tr(k), style = ui(15f, 700, if (on) G.cobalt2 else G.ink))
                    Text(tr("$k.s"), style = ui(12.5f, 400, G.ink2, 1.35f))
                }
            }
        }
    }
}

/** One line under the field: the laser's state or its reading; without a laser, the way to connect one. */
@Composable
private fun LaserLine(app: App, laser: String?) {
    val on = app.settings.laser == Laser.CONNECTED
    Row(Modifier.fillMaxWidth().heightIn(min = 40.dp).let { if (on) it else it.clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.sheet = Sheet.Device } }
        .padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(9.dp).clip(CircleShape).background(if (on) Color(0xFF16A34A) else G.ink3))
        Text(when { laser == "busy" -> tr("fx.busy"); laser != null -> laser; on -> tr("fx.laserOn"); else -> tr("fx.laserOff") }, style = ui(12.5f, 600, G.ink2, 1.35f), modifier = Modifier.weight(1f))
        if (!on) Text(tr("fx.connect"), style = ui(13.5f, 700, G.cobalt2))
    }
}

@Composable
private fun Summary(steps: List<uz.metrx.app.furniture.SizeStep>, texts: List<String>, derived: List<Triple<String, String, Boolean>>, note: String, onChange: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        steps.forEachIndexed { i, s ->
            Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(14.dp)).background(G.glass(.7f)).clickable(role = Role.Button) { onChange(i) }
                .padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(tr(s.label), style = ui(14.5f, 600), modifier = Modifier.weight(1f))
                Text(texts[i], style = num(17f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Text(tr("fz.change"), style = ui(12.5f, 700, G.cobalt2))
            }
        }
        // a corner piece: the sides worked out from the ones typed, marked as such
        if (derived.isNotEmpty()) DerivedCard(derived)
        Text(tr(note), style = ui(12.5f, 400, G.ink2, 1.45f), modifier = Modifier.padding(top = 4.dp, start = 4.dp))
    }
}

/* ---------------- which room ---------------- */

@Composable
fun FWhereScreen(rt: Route.FWhere) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val m = fModel(rt.model) ?: return
    val ws = app.settings.workshop
    val snap = app.settings.angleSnap
    val unit = app.settings.unit
    val vals = remember(rt) { decodeVals(rt.vals) }
    val probe = remember(rt) { pieceOf(m, vals, ws, "") }
    fun made(): uz.metrx.app.furniture.Furniture = pieceOf(m, vals, ws, app.pieceName(p, m), System.currentTimeMillis())
    val dv = uz.metrx.app.furniture.derive(m, vals)
    val sizes = stepsOf(m).filter { !it.choice && (it.key != "h" || m.kind != "kitchen") }.joinToString(if (m.kind == "kitchen") " + " else " × ") { s -> dv[s.key]?.let { fmtLen(it, unit, en) } ?: "?" } + " " + unitWord(unit)

    FPage(tr("fz.m.${m.id}"), tr("fq.title"), { app.pop() }) {
        Text(tr("fz.m.${m.id}") + ": " + sizes, style = ui(13.5f, 500, G.ink2))
        if (p.rooms.none { measuredRoom(it, snap) }) Text(tr("fz.noMeasured"), style = ui(13.5f, 400, G.ink2, 1.4f))
        p.rooms.forEach { r ->
            val w = p.floors.firstOrNull { it.id == r.floorId }
            val name = w?.let { floorName(it, lang) } ?: dn(r.name, lang)
            val ready = measuredRoom(r, snap)
            val fit = if (ready) remember(r, probe) { bestFirst(probe, walls(r, snap).map { it.id }, { id -> wallLen(r, snap, id) }, r.dim("H").v, ws) } else null
            Row(Modifier.fillMaxWidth().heightIn(min = 66.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(if (ready) .75f else .4f))
                .let { if (ready) it.clickable(role = Role.Button) { app.push(Route.FPlace(p.id, null, r.id, m.id, rt.vals)) } else it }
                .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon(if (w?.type == "kitchen") "kitchen" else "room", if (ready) G.cobalt else G.ink3, 24.dp, 2f)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(name, style = ui(15f, 700, if (ready) G.ink else G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (ready) {
                        val f = { mm: Int? -> fmtLen(mm, LenUnit.M, en) }
                        Text(f(r.dim("A").v) + " × " + f(r.dim("B").v) + " " + tr("u.m") + " · h " + f(r.dim("H").v), style = num(12.5f, 500, G.ink2))
                        val good = fit!!.second.isEmpty()
                        Text(if (good) "✓ " + tr("fq.fits") else issueText(app, fit.second.first(), lang), style = ui(12f, 700, if (good) Color(0xFF15803D) else G.err, 1.3f),
                            modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(if (good) G.greenWash else G.errWash).padding(horizontal = 8.dp, vertical = 3.dp))
                    } else Text(tr("fo.notMeasured"), style = ui(12.5f, 400, G.ink3))
                }
                if (ready) MIcon("chev", G.ink3, 16.dp, 2f)
            }
        }
        // a room still to measure: the piece is kept and goes in once the room is measured
        Row(Modifier.fillMaxWidth().heightIn(min = 66.dp).clip(RoundedCornerShape(16.dp)).dashedGlass(16.dp).clickable(role = Role.Button) {
            if (!app.once()) return@clickable
            val f = made(); app.addPiece(p.id, f)
            app.popTo { it is Route.Project && it.id == p.id }
            app.sheet = Sheet.FNewRoom(p.id, f.kind, f.id)
        }.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MIcon("plus", G.cobalt2, 22.dp, 2.2f)
            Column(Modifier.weight(1f)) {
                Text(tr("fz.newRoom"), style = ui(15f, 700, G.cobalt2))
                Text(tr("fq.newRoomS"), style = ui(12.5f, 400, G.ink2))
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 66.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.75f)).clickable(role = Role.Button) {
            if (!app.once()) return@clickable
            val f = made(); val moved = p.stage == "measure"
            app.addPiece(p.id, f)
            app.kit.sel = null
            app.popTo { it is Route.Project && it.id == p.id }
            app.push(app.designer(p.id, f, step = 2))
            app.say(if (moved) "fz.createdS" else "fz.created", "n" to dn(f.name, lang), "s" to app.t("fs.design"))
        }.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MIcon("ruler", G.cobalt, 22.dp, 2f)
            Column(Modifier.weight(1f)) {
                Text(tr("fq.none"), style = ui(15f, 700))
                Text(tr("fq.noneS"), style = ui(12.5f, 400, G.ink2))
            }
            MIcon("chev", G.ink3, 16.dp, 2f)
        }
    }
}
