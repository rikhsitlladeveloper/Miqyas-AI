package uz.metrx.app.ui.rooms

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.uid
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap

/*
 * "Nimadan boshlaymiz?" (room editor v2, task 2): after "Buyurtma yaratish" a sheet with two big cards — the room
 * first, or the trade's room-less way (furniture: design only; tiler: area only; electrician and plumber: a list;
 * builder: an estimate; windows: products only) — and a small "Keyinroq" for the order page. Tapping outside is
 * "Keyinroq" too. The choice is not remembered; the order page keeps both ways as buttons ([StartPaths]).
 */

/** The sheets of the room editor v2. False for the sheets it doesn't own. */
@Composable
fun RoomSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.StartOrder -> StartOrderSheet(s)
        else -> return false
    }
    return true
}

/** The order's trade as the start dialog names it: furniture, tiler, elec, plumb, win or build. */
fun tradeOf(p: Project): String = when {
    p.isFurniture -> "furniture"; p.isTiler -> "tiler"; p.isElec -> "elec"; p.isPlumb -> "plumb"; p.isWin -> "win"; else -> "build"
}

/** "Xonani o‘lchash": the trade's own "Xona qo‘shish" sheet (type and name), then the room flow. */
fun App.startRoomPath(pid: String) {
    val p = store.get(pid) ?: return
    haptic(Hap.TICK)
    sheet = when (tradeOf(p)) {
        "furniture" -> Sheet.FNewRoom(pid)
        "tiler" -> Sheet.TNewRoom(pid)
        "elec" -> Sheet.ENewRoom(pid)
        "plumb" -> Sheet.PNewRoom(pid)
        "win" -> Sheet.WNewRoom(pid)
        else -> {
            // a builder's room goes into a place: the first floor, made now when there is none
            val w = p.floors.firstOrNull() ?: Workspace(uid(), "@floor1", "floor", created = System.currentTimeMillis()).also { nw ->
                store.update(pid) { it.copy(floors = it.floors + nw) }
            }
            Sheet.NewRoom(pid, w.id)
        }
    }
}

/** The trade's room-less way: the gallery that needs no room, or the builder's estimate. */
fun App.startOtherPath(pid: String) {
    val p = store.get(pid) ?: return
    haptic(Hap.TICK)
    sheet = null
    when (tradeOf(p)) {
        "furniture" -> push(Route.FGallery(pid, fromNew = true))
        "tiler" -> push(Route.TGallery(pid, fromNew = true))
        "elec" -> push(Route.EGallery(pid, fromNew = true))
        "plumb" -> push(Route.PGallery(pid, fromNew = true))
        "win" -> push(Route.WGallery(pid, fromNew = true))
        else -> setProjectTab("estimate")
    }
}

@Composable
private fun StartOrderSheet(s: Sheet.StartOrder) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val tr0 = tradeOf(p)
    val lang = app.settings.lang
    fun later() { app.sheet = null; app.say("sd.laterToast") }
    GlassSheet(tr("sd.title"), ::later) {
        val who = dn(p.customer, lang).ifBlank { dn(p.name, lang) }
        Text(tr("sd.sub", "c" to who, "t" to tr("sd.tr.$tr0")), style = ui(13f, 500, G.ink2, 1.35f))
        StartCard("room", tr("sd.room"), tr("sd.a.$tr0"), tr(if (tr0 == "elec" || tr0 == "plumb") "sd.nx.roomPts" else "sd.nx.room")) { app.startRoomPath(p.id) }
        StartCard(when (tr0) { "build" -> "doc"; "elec", "plumb" -> "list"; "tiler" -> "tile"; "win" -> "window"; else -> "sofa" },
            tr("sd.b.$tr0"), tr("sd.bd.$tr0"), tr("sd.bn.$tr0")) { app.startOtherPath(p.id) }
        Text(tr("sd.later"), style = ui(15f, 700, G.ink2).copy(textDecoration = TextDecoration.Underline), textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(min = 48.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button, onClick = ::later)
                .padding(horizontal = 18.dp, vertical = 13.dp))
        Text(tr("sd.laterNote"), style = ui(12.5f, 500, G.ink2, 1.35f), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
}

/** A big card of the start dialog: icon, title, what happens, "Keyin: …" in blue, a chevron. */
@Composable
private fun StartCard(icon: String, title: String, body: String, next: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 118.dp).clip(shape).background(G.glass(.85f)).border(1.dp, G.rim, shape).clickable(role = Role.Button, onClick = onClick)
        .padding(start = 14.dp, end = 12.dp, top = 16.dp, bottom = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(54.dp).clip(RoundedCornerShape(17.dp)).background(G.cobalt.copy(alpha = .11f)), contentAlignment = Alignment.Center) { ReIcon(icon, G.cobalt2, 28.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = ui(16.5f, 800, G.ink, 1.2f))
            Text(body, style = ui(13f, 400, G.ink2, 1.35f))
            Text(next, style = ui(12.5f, 800, G.cobalt2, 1.3f), modifier = Modifier.padding(top = 2.dp))
        }
        ReIcon("chev", G.ink3, 20.dp, 2f)
    }
}

/** The order page's two ways while it has no room: the room-less one and "Xonani o‘lchash". */
@Composable
fun StartPaths(p: Project, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val t = tradeOf(p)
    Column(modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { ReIcon("room", G.cobalt, 26.dp, 2f) }
        Text(tr("sd.empty.t"), style = ui(16f, 800), textAlign = TextAlign.Center)
        Text(tr("sd.empty.b", "b" to tr("sd.b.$t")), style = ui(13.5f, 400, G.ink2, 1.4f), textAlign = TextAlign.Center)
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("sd.b.$t"), { app.startOtherPath(p.id) }, Btn.SECONDARY, height = 52.dp, corner = 16.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("sd.room"), { app.startRoomPath(p.id) }, icon = "plus", height = 52.dp, corner = 16.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
    }
}
