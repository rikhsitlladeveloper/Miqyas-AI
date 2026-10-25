package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.DESIGN_PRESETS
import uz.metrx.app.furniture.DesignPreset
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.KExtras
import uz.metrx.app.furniture.K_SPLASH
import uz.metrx.app.furniture.LOOK_COLOURS
import uz.metrx.app.furniture.LOOK_FABRICS
import uz.metrx.app.furniture.LOOK_STONES
import uz.metrx.app.furniture.LOOK_WOODS
import uz.metrx.app.furniture.Look
import uz.metrx.app.furniture.boardFor
import uz.metrx.app.furniture.colourOf
import uz.metrx.app.furniture.crownOf
import uz.metrx.app.furniture.handleType
import uz.metrx.app.furniture.middleFill
import uz.metrx.app.furniture.presetOf
import uz.metrx.app.furniture.refinish
import uz.metrx.app.furniture.splashFor
import uz.metrx.app.furniture.splashKind
import uz.metrx.app.furniture.withCrown
import uz.metrx.app.furniture.withHandleType
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withMiddleFill
import uz.metrx.app.furniture.withPreset
import uz.metrx.app.furniture.worktopDecor
import uz.metrx.app.furniture.worktopFor
import uz.metrx.app.furniture.worktopKind
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The design of a piece (modern 3D part 2, 25 Oct 2026; the approved mockup's bottom sheet): the six design style
 * presets as cards, then the fine options as rows of swatches and chips, the extras tagged "qo‘shimcha". The order's
 * own style, picked when it is made, is what new pieces start with ([FStyleScreen]). The look is everyone's; prices
 * stay in Advanced (the cost card). The rules are in furniture/Look.kt.
 */

private fun col(hex: String) = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.LightGray)

/** A colour, wood, stone or fabric key's colour. */
private fun rgbOf(key: String): String = LOOK_COLOURS.firstOrNull { it.key == key }?.rgb ?: LOOK_WOODS.firstOrNull { it.key == key }?.rgb ?: "#CCCCCC"

private val WOOD_SET = LOOK_WOODS.map { it.key }.toSet()

/** A swatch's picture: a colour, a wood's grain, a stone's vein, a velvet's sheen. */
private fun DrawScope.swatch(rgb: String, kind: String) {
    val c = col(rgb)
    drawRect(c)
    val on = if (c.red * .3f + c.green * .59f + c.blue * .11f > .55f) Color.Black.copy(alpha = .14f) else Color.White.copy(alpha = .16f)
    when (kind) {
        "wood" -> (1..5).forEach { i -> val y = size.height * i / 6f; drawLine(on, Offset(0f, y), Offset(size.width, y + size.height * .08f * (if (i % 2 == 0) 1 else -1)), 1.4f) }
        "stone" -> { drawLine(on.copy(alpha = .3f), Offset(0f, size.height * .3f), Offset(size.width, size.height * .75f), 1.6f); drawLine(on, Offset(size.width * .2f, 0f), Offset(size.width * .55f, size.height), 1f) }
        "velvet" -> drawRect(Color.White.copy(alpha = .12f), Offset(0f, 0f), Size(size.width, size.height * .45f))
    }
}

@Composable
private fun RowTitle(label: String, value: String? = null) {
    Text(if (value != null) "$label: $value" else label, style = ui(14f, 700), maxLines = 2, overflow = TextOverflow.Ellipsis)
}

/** A row of swatches ([items]: key, colour, kind wood/stone/velvet/""), [cur] the one on. */
@Composable
private fun Swatches(items: List<Triple<String, String, String>>, cur: String?, name: (String) -> String, onPick: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items.forEach { (k, rgb, kind) ->
            val on = k == cur
            Box(Modifier.size(44.dp).clip(CircleShape).border(if (on) 3.dp else 1.dp, if (on) G.cobalt else G.ink.copy(alpha = .2f), CircleShape)
                .semantics { selected = on; contentDescription = name(k) }.clickable(role = Role.RadioButton) { onPick(k) }.padding(if (on) 4.dp else 1.dp)) {
                Canvas(Modifier.fillMaxSize().clip(CircleShape)) { swatch(rgb, kind) }
            }
        }
    }
}

/** A row of chips: value, label, an extra ("qo‘shimcha"). */
@Composable
private fun Chips(items: List<Triple<String, String, Boolean>>, cur: String, onPick: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        items.forEach { (v, label, extra) -> Chip(if (extra) label + " · " + tr("lk.extra") else label, v == cur) { onPick(v) } }
    }
}

/* ---------------- a preset's card ---------------- */

/** A preset as a small kitchen: the upper and lower fronts in its colours, the worktop, its handles and crown. */
@Composable
internal fun PresetCard(p: DesignPreset, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val name = tr("lk.p.${p.id}")
    Column(modifier.clip(shape).glassCard(shape, fill = if (on) G.cobalt.copy(alpha = .1f) else G.glass(.62f)).border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape)
        .semantics { selected = on; contentDescription = name }.clickable(role = Role.RadioButton, onClick = onClick).padding(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(Modifier.fillMaxWidth().aspectRatio(1.45f).clip(RoundedCornerShape(12.dp)).background(Color(0xFFEDEAE4))) { presetPicture(p) }
        Text(name, style = ui(14f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(tr("lk.p.${p.id}.d"), style = ui(11.5f, 500, G.ink2, 1.3f), maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

private fun DrawScope.presetPicture(p: DesignPreset) {
    val w = size.width; val h = size.height
    val up = col(rgbOf(p.up)); val low = col(rgbOf(if (p.two) p.low else p.up))
    val hc = col(uz.metrx.app.furniture.HANDLE_RGB[p.hcol] ?: "#1E1F22")
    val topC = col(if (p.top == "wood") rgbOf(p.accent) else LOOK_STONES.firstOrNull { it.key == p.stone }?.rgb ?: "#F1EFEB")
    val x0 = w * .1f; val x1 = w * .9f
    val crownY = h * .08f
    val upY0 = if (p.crown == "ceiling") crownY else h * .16f; val upY1 = h * .44f
    val topY = h * .6f; val lowY1 = h * .9f
    if (p.crown == "cornice") drawRect(up, Offset(x0 - 3f, upY0 - h * .05f), Size(x1 - x0 + 6f, h * .05f))
    // the backsplash
    drawRect(if (p.splash == "tile") Color(0xFFF4F2EE) else if (p.splash == "print") Color(0xFFC9D6E2) else Color(0xFFE6E2DA), Offset(x0, upY1), Size(x1 - x0, topY - upY1))
    if (p.splash == "tile") (1..3).forEach { i -> val y = upY1 + (topY - upY1) * i / 4f; drawLine(Color.Black.copy(alpha = .08f), Offset(x0, y), Offset(x1, y), 1f) }
    val n = 3; val gap = 2f
    val dw = (x1 - x0 - gap * (n - 1)) / n
    for (i in 0 until n) {
        val lx = x0 + i * (dw + gap)
        drawRoundRect(up, Offset(lx, upY0), Size(dw, upY1 - upY0), CornerRadius(2f))
        drawRoundRect(low, Offset(lx, topY + h * .045f), Size(dw, lowY1 - topY - h * .045f), CornerRadius(2f))
        if (p.style == "shaker") {
            val st = Stroke(1.2f)
            drawRect(Color.Black.copy(alpha = .1f), Offset(lx + 4f, upY0 + 4f), Size(dw - 8f, upY1 - upY0 - 8f), style = st)
            drawRect(Color.Black.copy(alpha = .1f), Offset(lx + 4f, topY + h * .045f + 4f), Size(dw - 8f, lowY1 - topY - h * .045f - 8f), style = st)
        }
        // the handles: bars, long bars, knobs, the Gola channel
        val cx = lx + dw / 2
        when (p.handle) {
            "gola" -> {}
            "knob" -> { drawCircle(hc, 2.4f, Offset(cx, upY1 - 6f)); drawCircle(hc, 2.4f, Offset(cx, topY + h * .045f + 6f)) }
            else -> {
                val l = if (p.handle == "long") .5f else .25f
                drawLine(hc, Offset(cx, upY1 - 4f - (upY1 - upY0) * l), Offset(cx, upY1 - 4f), 2.2f, StrokeCap.Round)
                drawLine(hc, Offset(cx - dw * l / 2, topY + h * .045f + 5f), Offset(cx + dw * l / 2, topY + h * .045f + 5f), 2.2f, StrokeCap.Round)
            }
        }
    }
    if (p.handle == "gola") drawRect(Color(0xFF2A2B2E), Offset(x0, topY + h * .045f - 1f), Size(x1 - x0, 3f))
    // the worktop
    drawRect(topC, Offset(x0 - 3f, topY), Size(x1 - x0 + 6f, h * .045f))
    drawRect(Color.Black.copy(alpha = .08f), Offset(x0 - 3f, topY), Size(x1 - x0 + 6f, h * .045f), style = Stroke(.8f))
}

/** The presets in a row that scrolls sideways (a piece's design). */
@Composable
private fun PresetStrip(cur: String, onPick: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        DESIGN_PRESETS.forEach { p -> PresetCard(p, cur == p.id, Modifier.width(150.dp)) { onPick(p.id) } }
    }
}

/* ---------------- the design of a piece ---------------- */

/** What the piece is for the rows shown: a kitchen, a sliding wardrobe (kupe), a bed, another cabinet. */
private fun designKind(f: Furniture) = when {
    f.kind == "kitchen" -> "kitchen"
    f.modules.any { it.slide != null } -> "kupe"
    f.modules.any { it.type == "bed" } -> "bed"
    else -> "case"
}

/**
 * A piece's "Dizayn" section: the preset cards, the fronts' colours (two-tone where it applies), surface, style,
 * handles and their colour, the mirror, a bed's fabric and headboard, a kitchen's worktop, backsplash, LED, legs and
 * crown, and the extras.
 */
@Composable
fun DesignCard(p: Project, f: Furniture) {
    val app = LocalApp.current
    fun change(fn: (Furniture) -> Furniture) { app.kit.change(app, p.id, f.id, fn) }
    fun look(fn: (Look) -> Look) = change { withLook(it, fn) }
    val kind = designKind(f)
    val kitchen = kind == "kitchen"
    val l = f.look ?: Look()
    val style = l.style
    val finish = l.finish.ifEmpty { if (f.mats.front.startsWith("ag_")) "gloss" else "matte" }
    val fronts = LOOK_COLOURS.map { Triple(it.key, it.rgb, "") } + LOOK_WOODS.map { Triple(it.key, it.rgb, "wood") }
    fun frontName(k: String) = if (k in WOOD_SET) app.t("lk.w.$k") else app.t("lk.c.$k")
    fun boardName(id: String?): String = colourOf(id)?.let(::frontName) ?: app.settings.mats.firstOrNull { it.id == id }?.name ?: (id ?: "")
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("lk.title"), style = ui(16f, 800))
        Text(tr("lk.presets"), style = ui(12.5f, 400, G.ink2, 1.4f))
        PresetStrip(presetOf(f)) { id -> change { withPreset(it, id) }; app.say("lk.applied", "n" to app.t("lk.p.$id")) }
        Hairline()
        // the fronts' colours: one, or the upper and the lower (a kitchen's rows, a kupe's doors above and below the split)
        val twoOn = f.mats.frontUp != null
        if (kind == "kitchen" || kind == "kupe") Toggle(tr("lk.two"), twoOn) {
            change { g -> withLook(g) { it }.let { x -> x.copy(mats = x.mats.copy(frontUp = if (x.mats.frontUp != null) null else x.mats.front)) } }
        }
        fun setFront(up: Boolean, k: String) = change { g ->
            withLook(g) { it }.let { x -> val b = boardFor(k, finish, style); x.copy(mats = if (up) x.mats.copy(frontUp = b) else x.mats.copy(front = b)) }
        }
        if (twoOn) {
            RowTitle(tr("lk.upFront"), boardName(f.mats.frontUp))
            Swatches(fronts, colourOf(f.mats.frontUp), ::frontName) { setFront(true, it) }
            RowTitle(tr("lk.lowFront"), boardName(f.mats.front))
            Swatches(fronts, colourOf(f.mats.front), ::frontName) { setFront(false, it) }
        } else {
            RowTitle(tr(if (kind == "bed") "lk.bedColour" else "lk.front"), boardName(f.mats.front))
            Swatches(fronts, colourOf(f.mats.front), ::frontName) { setFront(false, it) }
        }
        // the colour fronts' surface and the fronts' style: the boards follow (an enamel board for milled or fluted fronts)
        fun refit(fin: String, st: String) = change { g ->
            withLook(g) { it.copy(finish = fin, style = st) }.let { x -> x.copy(mats = x.mats.copy(front = refinish(x.mats.front, fin, st), frontUp = x.mats.frontUp?.let { refinish(it, fin, st) })) }
        }
        RowTitle(tr("lk.finish"))
        Chips(listOf(Triple("gloss", tr("lk.f.gloss"), false), Triple("matte", tr("lk.f.matte"), false)), finish) { refit(it, style) }
        RowTitle(tr("lk.style"))
        Chips(listOf(Triple("flat", tr("lk.s.flat"), false), Triple("shaker", tr("lk.s.shaker"), false), Triple("fluted", tr("lk.s.fluted"), true)), style) { refit(finish, it) }
        // handles (sliding doors have none: their profile's colour only)
        if (kind != "kupe") {
            RowTitle(tr("lk.handle"))
            Chips(listOfNotNull(Triple("bar", tr("lk.h.bar"), false), Triple("long", tr("lk.h.long"), false), Triple("knob", tr("lk.h.knob"), false),
                if (kitchen) Triple("gola", tr("lk.h.gola"), false) else null, Triple("push", tr("lk.h.push"), false)), handleType(f)) { v -> change { withLook(withHandleType(it, v)) { x -> x } } }
        }
        RowTitle(tr(if (kind == "kupe") "lk.hcolK" else "lk.hcol"))
        Chips(listOf("black", "brass", "gold", "chrome").map { Triple(it, tr("lk.hc.$it"), false) }, l.hcol) { v -> look { it.copy(hcol = v) } }
        // a kupe's middle door: a mirror in its tint, or lacobel glass, or the front board
        if (kind == "kupe") {
            val fill = middleFill(f) ?: "ldsp"
            val cur = when (fill) { "mirror" -> l.mirror.ifEmpty { "silver" }; "glass" -> "lacobel"; else -> "ldsp" }
            RowTitle(tr("lk.mirror"))
            Chips(listOf(Triple("silver", tr("lk.m.silver"), false), Triple("bronze", tr("lk.m.bronze"), false), Triple("graphite", tr("lk.m.graphite"), false),
                Triple("lacobel", tr("lk.m.lacobel"), false), Triple("ldsp", tr("lk.m.ldsp"), false)), cur) { v ->
                change { g -> when (v) { "lacobel" -> withMiddleFill(withLook(g) { it }, "glass"); "ldsp" -> withMiddleFill(withLook(g) { it }, "ldsp")
                    else -> withMiddleFill(withLook(g) { it.copy(mirror = v) }, "mirror") } }
            }
        } else if (f.modules.any { m -> m.sections.any { it.face == "mirror" } || m.type == "mirror" || (m.opt?.mirW ?: 0) > 0 }) {
            RowTitle(tr("lk.mirrorTint"))
            Chips(listOf("silver", "bronze", "graphite").map { Triple(it, tr("lk.m.$it"), false) }, l.mirror.ifEmpty { "silver" }) { v -> look { it.copy(mirror = v) } }
        }
        // a bed: the fabric, the headboard, the soft wall panel
        if (kind == "bed") {
            RowTitle(tr("lk.fabric"), l.fabric.takeIf { it.isNotEmpty() }?.let { tr("lk.fab.$it") })
            Swatches(LOOK_FABRICS.map { Triple(it.key, it.rgb, if (it.velvet) "velvet" else "") }, l.fabric, { app.t("lk.fab.$it") }) { v -> look { it.copy(fabric = v) } }
            RowTitle(tr("lk.head"))
            Chips(listOf("", "vertical", "tufted", "panels").map { Triple(it, tr("lk.hb.${it.ifEmpty { "board" }}"), false) }, l.head) { v -> look { it.copy(head = v) } }
            Toggle(tr("lk.panel"), l.panel) { look { it.copy(panel = !it.panel) } }
        }
        if (kitchen) {
            // the worktop: its kind, then its decor
            val tk = worktopKind(f.mats.top)
            RowTitle(tr("lk.top"))
            Chips(listOf(Triple("plain", tr("lk.t.plain"), false), Triple("stone", tr("lk.t.stone"), false), Triple("wood", tr("lk.t.wood"), false), Triple("slim", tr("lk.t.slim"), true)), tk) { v ->
                change { g -> withLook(g) { it }.let { x ->
                    val d = worktopDecor(x.mats.top).let { d -> if (v == "wood") d.takeIf { it == "craft" || it == "halifax" } ?: "craft" else d.takeIf { it in setOf("marble", "onyx", "dark") } ?: "marble" }
                    x.copy(mats = x.mats.copy(top = if (v == "plain") null else worktopFor(v, d)))
                } }
            }
            if (tk != "plain") {
                val decors = if (tk == "wood") LOOK_WOODS.filter { it.key == "craft" || it.key == "halifax" }.map { Triple(it.key, it.rgb, "wood") }
                    else LOOK_STONES.map { Triple(it.key, it.rgb, "stone") }
                fun decorName(k: String) = if (tk == "wood") app.t("lk.w.$k") else app.t("lk.st.$k")
                val cur = worktopDecor(f.mats.top)
                RowTitle(tr("lk.topDecor"), decorName(cur))
                Swatches(decors, cur, ::decorName) { v -> change { g -> withLook(g) { it }.let { x -> x.copy(mats = x.mats.copy(top = worktopFor(tk, v))) } } }
            }
            // the backsplash: the workshop's panel, skinali plain or printed, tile (600 high when there was none)
            RowTitle(tr("lk.splash"))
            Chips(listOf(Triple("", tr("lk.sp.panel"), false), Triple("glass", tr("lk.sp.glass"), false), Triple("print", tr("lk.sp.print"), false), Triple("tile", tr("lk.sp.tile"), false)),
                splashKind(f.mats.splash)) { v ->
                change { g -> withLook(g) { it }.let { x -> x.copy(mats = x.mats.copy(splash = splashFor(v)),
                    kx = (x.kx ?: KExtras()).let { k -> if (k.splash == 0) k.copy(splash = K_SPLASH) else k }) } }
            }
        }
        // a wood accent: open shelves and insides, a bed's bedside tops
        if (kitchen || kind == "bed") {
            val cur = l.accent.removePrefix("wd_")
            RowTitle(tr("lk.accent"), cur.takeIf { it.isNotEmpty() }?.let { tr("lk.w.$it") })
            Swatches(LOOK_WOODS.map { Triple(it.key, it.rgb, "wood") }, cur, { app.t("lk.w.$it") }) { v -> look { it.copy(accent = "wd_$v") } }
        }
        // LED: a kitchen's under the wall units (its extras), a wardrobe's inside with a door sensor
        if (kitchen) Toggle(tr("lk.led"), f.kx?.led == true) { change { g -> withLook(g) { it }.let { x -> x.copy(kx = (x.kx ?: KExtras()).copy(led = x.kx?.led != true)) } } }
        // (a gorka's LED is on its own card: GorkaViews.kt)
        else if (kind == "kupe" || (kind == "case" && f.type != "gorka" && f.modules.any { it.type == "wardrobe" && it.sections.any { s -> s.fronts.kind == "door" } })) Toggle(tr("lk.ledW"), l.led) { look { it.copy(led = !it.led) } }
        if (kitchen) {
            RowTitle(tr("lk.legs"))
            Chips(listOf(Triple("plinth", tr("lk.l.plinth"), false), Triple("metal", tr("lk.l.metal"), true)), if (l.legs) "metal" else "plinth") { v -> look { it.copy(legs = v == "metal") } }
            RowTitle(tr("lk.crown"))
            Chips(listOf(Triple("", tr("lk.c0"), false), Triple("cornice", tr("lk.cCornice"), false), Triple("ceiling", tr("lk.cCeiling"), false)), crownOf(f)) { v ->
                change { withLook(withCrown(it, v)) { x -> x } }
            }
        }
        // the extras
        val glass = f.modules.any { m -> m.sections.any { it.face == "glass" } }
        if (kitchen || glass) Toggle(tr("lk.fglass") + " · " + tr("lk.extra"), l.fglass) { look { it.copy(fglass = !it.fglass) } }
        if (kitchen && (f.layout == "O" || f.layout == "P")) Toggle(tr("lk.waterfall") + " · " + tr("lk.extra"), l.waterfall) { look { it.copy(waterfall = !it.waterfall) } }
        if (kitchen && !glass) Text(tr("lk.fglassNote"), style = ui(12f, 400, G.ink2, 1.4f))
    }
}

/* ---------------- the order's style ---------------- */

/**
 * The order's design style (a new order's first step, or from the gallery): six preset cards; new pieces start with
 * the one picked. [Route.FStyle.fromNew] goes on to the gallery.
 */
@Composable
fun FStyleScreen(rt: Route.FStyle) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    fun next() { if (rt.fromNew) app.replaceTop(Route.FGallery(p.id, fromNew = true)) else app.pop() }
    fun pick(id: String) {
        if (!app.once()) return
        app.store.update(p.id) { it.copy(fstyle = id) }
        next()
    }
    FPage(dn(p.name, lang), tr("lk.styleT"), { app.pop() }) {
        Text(tr("lk.styleS"), style = ui(13.5f, 400, G.ink2, 1.45f))
        DESIGN_PRESETS.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { d -> PresetCard(d, p.fstyle == d.id, Modifier.weight(1f)) { pick(d.id) } }
            }
        }
        if (rt.fromNew) Text(tr("lk.later"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 4.dp)
            .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { if (app.once()) next() }.padding(horizontal = 16.dp, vertical = 12.dp))
    }
}

/** On the gallery: the order's style and the way to change it. */
@Composable
internal fun StyleRow(p: Project) {
    val app = LocalApp.current
    val d = DESIGN_PRESETS.firstOrNull { it.id == p.fstyle }
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(18.dp)).glassCard(RoundedCornerShape(18.dp), fill = G.glass(.6f))
        .clickable(role = Role.Button) { app.push(Route.FStyle(p.id)) }.padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (d != null) Canvas(Modifier.size(54.dp, 38.dp).clip(RoundedCornerShape(8.dp)).background(Color(0xFFEDEAE4))) { presetPicture(d) }
        else MIcon("sliders", G.cobalt, 22.dp, 2f)
        Column(Modifier.weight(1f)) {
            Text(tr("lk.styleT"), style = ui(12f, 500, G.ink2))
            Text(if (d != null) tr("lk.p.${d.id}") else tr("lk.noStyle"), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        MIcon("chev", G.ink3, 16.dp, 2f)
    }
}
