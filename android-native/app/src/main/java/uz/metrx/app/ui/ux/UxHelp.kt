package uz.metrx.app.ui.ux

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.newProject
import uz.metrx.app.data.uid
import uz.metrx.app.furniture.AkApp
import uz.metrx.app.furniture.akPieces
import uz.metrx.app.furniture.akPlan
import uz.metrx.app.furniture.akSite
import uz.metrx.app.furniture.akStart
import uz.metrx.app.furniture.akWallsFor
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.furniture.wallLen
import uz.metrx.app.ui.main.Tab
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Help for furniture makers (UX upgrades §11): three tour cards on first launch with "O‘tkazib yuborish"; then a coach
 * mark the first time on each screen (order, gallery, size, designer, price); the "Namuna — oshxona" sample order.
 * Profile → "Maslahatlarni qayta ko‘rsatish" brings all three back.
 */

/* ---------------- the sample order ---------------- */

/**
 * "Namuna — oshxona": a measured 3400 × 2600 kitchen with an L kitchen in "Tabiiy yog‘och" built by the auto kitchen,
 * marked as the sample (a NAMUNA badge; never counted in reports, totals or counts). Made once; again after a reset.
 */
fun App.makeSample() {
    if (store.projects.any { it.sample }) { settings.setSampleMadeTo(true); return }
    val now = System.currentTimeMillis()
    val lang = settings.lang
    val w = Workspace(uid(), uz.metrx.app.data.suggestedName(t("fr.kitchen"), "fr.kitchen", lang), type = "kitchen", created = now)
    val room = Room(uid(), w.id, w.name, created = now,
        dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    val snap = settings.angleSnap
    val ws = settings.workshop
    val pieces = runCatching {
        val site = akSite(room, { wallLen(room, snap, it) }, snap)
        val walls = akWallsFor(site, "L", akStart(site)) ?: akStart(site)
        val plan = akPlan(site, walls, uz.metrx.app.furniture.akLayoutOf(site, walls) ?: "L", AkApp(), "wood", ws)
        plan?.let { akPieces(it, site, ws, listOf("@kt.nameN?n=1", "@kt.nameN?n=2"), now) } ?: emptyList()
    }.getOrDefault(emptyList())
    val p = newProject("@ux.sampleName", "@ux.sampleClient", "", "", null, settings.currency, settings.reportLang.code)
        .copy(industry = "furniture", sample = true, fstyle = "wood", floors = listOf(w), rooms = listOf(room), furniture = pieces,
            stage = if (pieces.isEmpty()) "measure" else "design", want = listOf("kitchen"), designed = pieces.isNotEmpty(), created = now - 1, edited = now - 1)
    store.add(p)
    settings.setSampleMadeTo(true)
}

/** The sample goes in one tap, with Undo. */
fun App.deleteSample(pid: String) {
    val gone = store.delete(pid) ?: return
    dropMissing()
    act(t("ux.sampleDel"), { store.restore(gone.first, gone.second) })
}

/* ---------------- the tour and the coach marks ---------------- */

/** Which coach mark the page on top has (null: none), and the target it points at. */
private fun App.coachKey(): String? = when (val r = top) {
    is Route.Project -> if (store.get(r.id)?.isFurniture == true) "order" else null
    is Route.FGallery -> "gallery"
    is Route.FSteps -> "size"
    is Route.Kitchen, is Route.Wardrobe -> "designer"
    is Route.FPrice -> "price"
    else -> null
}

@Composable
fun HelpLayer() {
    val app = LocalApp.current
    val s = app.settings
    if (!s.furniture) return
    // the sample order is made on the first launch as a furniture maker (and after "Maslahatlarni qayta ko‘rsatish")
    LaunchedEffect(s.sampleMade, s.furniture) { if (!s.sampleMade) app.makeSample() }
    if (!s.tourDone) {
        if (app.tab == Tab.HOME && app.top == Route.Root && app.sheet == null) Tour()
        return
    }
    Coach()
}

@Composable
private fun Tour() {
    val app = LocalApp.current
    var i by remember { mutableIntStateOf(0) }
    val cards = listOf("ux.tour1" to "mic", "ux.tour2" to "cube", "ux.tour3" to "tg")
    fun done() { app.haptic(Hap.TICK); app.settings.setTourSeen(true) }
    Box(Modifier.fillMaxSize().background(G.scrim).clickable(remember { MutableInteractionSource() }, null) {}, contentAlignment = Alignment.BottomCenter) {
        Column(Modifier.navigationBarsPadding().padding(12.dp).fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(G.solid).padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            TourPicture(i)
            Text(tr("ux.tourN", "i" to i + 1), style = ui(12.5f, 700, G.cobalt2))
            Text(tr(cards[i].first + ".t"), style = ui(21f, 800, G.ink, 1.2f))
            Text(tr(cards[i].first + ".b"), style = ui(14.5f, 400, G.ink2, 1.45f))
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    cards.indices.forEach { k -> Box(Modifier.size(if (k == i) 18.dp else 7.dp, 7.dp).clip(CircleShape).background(if (k == i) G.cobalt else G.ink.copy(alpha = .15f))) }
                }
                Box(Modifier.weight(1f))
                if (i < cards.lastIndex) Text(tr("ux.skip"), style = ui(14.5f, 700, G.ink2),
                    modifier = Modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { done() }.padding(horizontal = 10.dp, vertical = 14.dp))
                Text(tr(if (i < cards.lastIndex) "common.next" else "ux.start"), style = ui(15.5f, 800, Color.White),
                    modifier = Modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt).pressable({
                        if (i < cards.lastIndex) { app.haptic(Hap.TICK); i++ } else done()
                    }).padding(horizontal = 20.dp, vertical = 14.dp))
            }
        }
    }
}

/** The tour cards' pictures: a size and the mic; the 3D gallery; the quote going to Telegram (the mockup's drawings). */
@Composable
private fun TourPicture(i: Int) {
    val blue = G.cobalt
    Box(Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(20.dp)).background(Color(0xFFE8EDFB)), contentAlignment = Alignment.Center) {
        when (i) {
            0 -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                Column(Modifier.clip(RoundedCornerShape(14.dp)).background(Color.White).padding(horizontal = 18.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("3400", style = ui(32f, 800, Color(0xFF0F172A)))
                    Text("mm", style = ui(12f, 600, Color(0xFF64748B)))
                }
                Box(Modifier.size(70.dp).clip(CircleShape).background(Color(0xFF0F172A)), contentAlignment = Alignment.Center) { UxIcon("mic", Color.White, 32.dp, 2.4f) }
            }
            1 -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(Color(0xFFA67A52), Color(0xFF3F4650), Color(0xFFF6F7F9)).forEach { c ->
                    Canvas(Modifier.size(78.dp, 96.dp).clip(RoundedCornerShape(12.dp)).background(Color.White)) {
                        val w = size.width; val h = size.height
                        drawRect(c, Offset(w * .15f, h * .45f), Size(w * .7f, h * .38f))
                        drawRect(Color(0xFFEDEAE4), Offset(w * .15f, h * .15f), Size(w * .7f, h * .22f))
                        drawRect(Color(0xFF0F172A).copy(alpha = .2f), Offset(w * .15f, h * .43f), Size(w * .7f, h * .03f))
                    }
                }
            }
            else -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(Modifier.size(70.dp, 92.dp).clip(RoundedCornerShape(10.dp)).background(Color.White).padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(30.dp, 5.dp).clip(RoundedCornerShape(3.dp)).background(blue))
                    Box(Modifier.size(46.dp, 4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFFE2E8F0)))
                    Box(Modifier.size(38.dp, 4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFFE2E8F0)))
                    Box(Modifier.weight(1f))
                    Box(Modifier.size(46.dp, 7.dp).clip(RoundedCornerShape(4.dp)).background(Color(0xFF0F172A)))
                }
                Box(Modifier.size(76.dp).clip(CircleShape).background(Color(0xFF2AABEE)), contentAlignment = Alignment.Center) { UxIcon("tg", Color.White, 38.dp) }
            }
        }
    }
}

/** The coach mark of the page on top, once: a ring round its target and a bubble with "Tushunarli". */
@Composable
private fun Coach() {
    val app = LocalApp.current
    val key = app.coachKey() ?: return
    if (key in app.settings.coachSeen || app.sheet != null) return
    val rect = app.coach[key]
    var show by remember(key) { mutableStateOf(false) }
    LaunchedEffect(key, rect != null) {
        if (rect == null) return@LaunchedEffect
        delay(600)
        if (app.sheet == null && app.coach[key] != null) { show = true; app.settings.markCoach(key) }
    }
    val r = app.coach[key]
    if (!show || r == null) return
    val density = LocalDensity.current
    fun close() { show = false }
    AnimatedVisibility(true, enter = fadeIn(), exit = fadeOut()) {
        BoxWithConstraints(Modifier.fillMaxSize().background(Color(0x66000000)).clickable(remember { MutableInteractionSource() }, null) { close() }) {
            val pad = with(density) { 6.dp.toPx() }
            Canvas(Modifier.fillMaxSize()) {
                drawRoundRect(Color.White, Offset(r.left - pad, r.top - pad), Size(r.width + 2 * pad, r.height + 2 * pad), CornerRadius(22f, 22f), style = Stroke(with(density) { 3.dp.toPx() }))
            }
            val hPx = with(density) { maxHeight.toPx() }
            val below = r.center.y < hPx / 2
            val y = if (below) r.bottom + pad * 3 else r.top - pad * 3
            val place = if (below) Modifier.offset { IntOffset(0, y.toInt()) }
                else Modifier.align(Alignment.BottomCenter).padding(bottom = with(density) { (hPx - y).coerceAtLeast(0f).toDp() })
            Column(place.padding(horizontal = 20.dp).fillMaxWidth().widthIn(max = 420.dp).clip(RoundedCornerShape(20.dp)).background(G.solid)
                .border(1.dp, G.rim, RoundedCornerShape(20.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tr("ux.c.$key.t"), style = ui(16.5f, 800, G.ink, 1.25f))
                Text(tr("ux.c.$key.b"), style = ui(14f, 400, G.ink2, 1.4f))
                Text(tr("ux.c.ok"), style = ui(14.5f, 800, Color.White), modifier = Modifier.align(Alignment.End).padding(top = 4.dp).heightIn(min = 44.dp)
                    .clip(RoundedCornerShape(14.dp)).background(G.cobalt).clickable(role = Role.Button) { close() }.padding(horizontal = 18.dp, vertical = 12.dp))
            }
        }
    }
}

/** Profile → "Maslahatlarni qayta ko‘rsatish": the tour, the coach marks and the sample order come back. */
fun App.resetUxHelp() {
    settings.resetUxHints()
    makeSample()
    say("ux.hints.done", kind = ToastKind.OK)
}

/** Profile's reset, for callers outside this package. */
object HelpOps {
    /** Every tip comes back: the editor's, the tour, the coach marks, and the sample order. */
    fun App.resetAll() { ops.tipSeen = false; resetUxHelp(); selectTab(Tab.HOME) }
}
