@file:OptIn(ExperimentalSerializationApi::class)

package uz.metrx.app.furniture

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable

/*
 * The design of a piece (modern 3D part 2, founder's decisions of 25 Oct 2026, the approved mockup
 * scratchpad modern3d/modern-3d.html): six design style presets, the fronts' style, handle colours, the kitchen's crown,
 * legs and island end, mirror tints, a bed's headboard and fabric. The boards stay in [FMats] (fronts, the upper
 * fronts of a two-tone kitchen, the worktop and the backsplash); the handle's type in [Furniture.handle]; the plinth,
 * cornice and LED of a kitchen in [KExtras]. Everything else is one small [Look] on the piece, null on a piece made
 * before (it looks and costs as it did). The 3D reads it all through [lookOf]. Pure Kotlin, unit-tested (LookTest).
 */

/** [Furniture.handle] for a kitchen's Gola profile: the fronts open by the channel, no handles (Hardware.kt). */
const val GOLA = "gola"

/** [Furniture.handle] for long verticals: 1024 on tall doors, 640 on the others, 320 on drawers ([longHandleIds]). */
const val LONG_V = "longV"

/** The texture ids the 3D draws boards and fabrics with (Decors.kt; the renderer's own files, part 1). */
val TEX_IDS = listOf("oak_light", "oak_tobacco", "oak_golden", "oak_dark", "walnut", "wenge", "marble_white", "onyx_beige", "stone_dark",
    "skinali_print", "tile_white", "boucle", "velvet", "fabric", "fluted", "fluted_glass")

/**
 * A piece's design. Written only when set (an older piece has none). [preset] the design style preset it was last set
 * to ("" none, or changed since); [style] the fronts: "flat", "shaker" (milled frame, neoclassic) or "fluted" (an extra);
 * [finish] the colour fronts' surface "gloss" or "matte" (the boards follow it; an enamel board shows it); [hcol] the
 * handles' and frames' colour: black, brass, gold, chrome ("" as drawn before); [crown] on top: "" none, "cornice",
 * "ceiling" a row of units up to the ceiling (a kitchen's cornice is [KExtras.cornice]); [legs] a kitchen on visible
 * metal legs instead of the plinth (an extra); [fglass] fluted glass in the glass doors (an extra); [waterfall] the
 * island's worktop runs down its ends (an extra); [mirror] the mirrors' tint: silver, bronze, graphite ("" silver);
 * [led] a wardrobe's LED inside with a door sensor; a bed's [head] ("" a plain board, "vertical" channels, "tufted"
 * carriage-tufted, "panels" square panels), [fabric] (Decors.kt LOOK_FABRICS) and soft wall [panel]; [accent] the wood
 * accent's board (open shelves, insides, bedside tops; "" none).
 */
@Serializable
data class Look(
    @EncodeDefault(EncodeDefault.Mode.NEVER) val preset: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val style: String = "flat",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val finish: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val hcol: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val crown: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val legs: Boolean = false,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val fglass: Boolean = false,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val waterfall: Boolean = false,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val mirror: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val led: Boolean = false,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val head: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val fabric: String = "",
    @EncodeDefault(EncodeDefault.Mode.NEVER) val panel: Boolean = false,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val accent: String = ""
)

/**
 * A design style preset (the mockup's PRESETS, approved 25 Oct 2026): the upper and lower fronts' colour ([two]-tone or
 * one), finish, style, handle (bar, long, knob, gola), handle colour, the worktop (stone or wood; [stone] its decor),
 * backsplash (glass, print, tile), crown (none, cornice, ceiling), wood accent, mirror tint, a bed's fabric and headboard.
 * Names and lines are strings lk.p.<id> and lk.p.<id>.d.
 */
data class DesignPreset(
    val id: String, val up: String, val low: String, val two: Boolean, val finish: String, val style: String, val handle: String, val hcol: String,
    val top: String, val stone: String, val splash: String, val crown: String, val accent: String, val mirror: String, val fabric: String, val head: String
)

/** Exactly the six approved presets, in the mockup's order. */
val DESIGN_PRESETS = listOf(
    DesignPreset("twotone", "white", "graphite", true, "gloss", "flat", "bar", "black", "stone", "marble", "glass", "none", "walnut", "graphite", "olive", "vertical"),
    DesignPreset("gloss", "white", "white", false, "gloss", "flat", "long", "chrome", "stone", "marble", "print", "none", "halifax", "silver", "grey", "panels"),
    DesignPreset("gola", "cashmere", "cashmere", false, "matte", "flat", "gola", "black", "wood", "onyx", "tile", "none", "craft", "bronze", "mocha", "vertical"),
    DesignPreset("neo", "ivory", "ivory", false, "matte", "shaker", "knob", "gold", "stone", "onyx", "tile", "cornice", "walnut", "bronze", "cream", "tufted"),
    DesignPreset("wood", "white", "halifax", true, "matte", "flat", "bar", "black", "stone", "marble", "tile", "none", "halifax", "silver", "cream", "panels"),
    DesignPreset("dark", "graphite", "black", true, "matte", "flat", "long", "brass", "stone", "dark", "glass", "ceiling", "walnut", "bronze", "navy", "vertical")
)

fun designPreset(id: String?): DesignPreset? = DESIGN_PRESETS.firstOrNull { it.id == id }

/* ---------------- boards ---------------- */

private val WOOD_KEYS = LOOK_WOODS.map { it.key }.toSet()
private val COLOUR_KEYS = LOOK_COLOURS.map { it.key }.toSet()

/**
 * The front board of a colour or wood [colour] (Decors.kt keys): a wood decor as it is; a colour as gloss acrylic or
 * soft-touch matte for flat fronts, as MDF enamel for milled (shaker) and fluted ones.
 */
fun boardFor(colour: String, finish: String, style: String): String = when {
    colour in WOOD_KEYS -> "wd_$colour"
    style == "shaker" || style == "fluted" -> "en_$colour"
    finish == "gloss" -> "ag_$colour"
    else -> "sm_$colour"
}

/** A decor board's colour or wood key (null: another board, e.g. an older order's LDSP). */
fun colourOf(board: String?): String? {
    if (board == null || board.length < 4 || board[2] != '_') return null
    val k = board.substring(3)
    return when (board.substring(0, 3)) { "ag_", "sm_", "en_" -> k.takeIf { it in COLOUR_KEYS }; "wd_" -> k.takeIf { it in WOOD_KEYS }; else -> null }
}

/** [board] again for [finish] and [style] (another family of the same colour); a board that is not a decor stays. */
fun refinish(board: String, finish: String, style: String): String = colourOf(board)?.let { boardFor(it, finish, style) } ?: board

/** The worktop of a kind ("stone", "wood", "slim") and decor (stone: marble, onyx, dark; wood: craft, halifax). */
fun worktopFor(kind: String, decor: String): String = when (kind) {
    "wood" -> if (decor == "halifax") "wt38h" else "wt38c"
    "slim" -> "wt20" + stoneCode(decor)
    else -> "wt38" + stoneCode(decor)
}

private fun stoneCode(decor: String) = when (decor) { "onyx" -> "o"; "dark" -> "d"; else -> "m" }

/** A worktop's kind: "plain" (the usual wt38, or the workshop's own), "stone", "wood", "slim". */
fun worktopKind(id: String?): String = when (id) {
    "wt38m", "wt38o", "wt38d" -> "stone"; "wt38c", "wt38h" -> "wood"; "wt20m", "wt20o", "wt20d" -> "slim"; else -> "plain"
}

/** A worktop's decor key: marble, onyx, dark, craft, halifax ("" none). */
fun worktopDecor(id: String?): String = when (id) {
    "wt38m", "wt20m" -> "marble"; "wt38o", "wt20o" -> "onyx"; "wt38d", "wt20d" -> "dark"; "wt38c" -> "craft"; "wt38h" -> "halifax"; else -> ""
}

/** The backsplash of a kind: glass (plain skinali), print (printed skinali), tile; "" the workshop's panel. */
fun splashFor(kind: String): String? = when (kind) { "glass" -> "skGlass"; "print" -> "skPrint"; "tile" -> "spTile"; else -> null }

fun splashKind(id: String?): String = when (id) { "skGlass" -> "glass"; "skPrint" -> "print"; "spTile" -> "tile"; else -> "" }

/** The worktop a piece uses (a kitchen's, a table's or a bar's of worktop board). */
fun worktopOf(f: Furniture): String = f.mats.top ?: "wt38"

/** The backsplash a kitchen uses: its own, or the list's first (as before 25 Oct 2026). */
fun splashOf(f: Furniture, mats: List<Mat>): Mat? = f.mats.splash?.let { id -> mats.firstOrNull { it.id == id } } ?: mats.firstOrNull { it.kind == "splash" }

/** Whether box [m] of [f] takes the upper fronts' board: a kitchen's wall units, another piece's hung boxes. */
fun isUpperFront(f: Furniture, m: Module): Boolean = if (f.kind == "kitchen") isUpper(m) else m.elev >= 1000

/** The front board of box [m] of [f]: the upper fronts' for [isUpperFront], else the fronts'. */
fun frontOf(f: Furniture, m: Module?): String = if (m != null && isUpperFront(f, m)) f.mats.frontUp ?: f.mats.front else f.mats.front

/** Two colours: the upper fronts differ from the lower ones. */
fun isTwoTone(f: Furniture) = f.mats.frontUp != null && f.mats.frontUp != f.mats.front

/* ---------------- handles, crown, legs ---------------- */

/** The handle's type as the design shows it: "bar", "long", "knob", "gola" or "push" (no handles). */
fun handleType(f: Furniture): String = when {
    f.handle == GOLA && f.kind == "kitchen" -> "gola"
    f.modules.any { takesHandles(it) && handleFronts(it).isNotEmpty() } && !hasHandles(f) -> "push"
    f.handle == LONG_V || f.handle == "handleLong" || f.handle == "handle640" || f.handle == "handle1024" -> "long"
    f.handle == "handleKnob" -> "knob"
    else -> "bar"
}

/** [Furniture.handle] for a design's handle type; a Gola profile only on a kitchen (another piece opens by a push). */
fun handleIdFor(type: String, f: Furniture): String = when (type) {
    "long" -> LONG_V; "knob" -> "handleKnob"; "gola" -> if (f.kind == "kitchen") GOLA else NO_HANDLES; "push" -> NO_HANDLES; else -> ""
}

/** [f] with handles of [type] (bar, long, knob, gola, push), the fronts chosen without one kept (Swap.kt). */
fun withHandleType(f: Furniture, type: String): Furniture = swapAll(listOf(f), handle = handleIdFor(type, f)).single()

/** On top of the piece: "", "cornice" or "ceiling"; a kitchen's cornice is its extras'. */
fun crownOf(f: Furniture): String = if (f.kind == "kitchen" && f.kx?.cornice == true) "cornice" else f.look?.crown ?: ""

/** [f] with [crown] on top ("", "cornice", "ceiling"): a kitchen's cornice goes in its extras, the rest in the look. */
fun withCrown(f: Furniture, crown: String): Furniture {
    val l = (f.look ?: Look())
    return if (f.kind == "kitchen") f.copy(kx = (f.kx ?: KExtras()).copy(cornice = crown == "cornice"), look = l.copy(crown = if (crown == "ceiling") "ceiling" else ""))
    else f.copy(look = l.copy(crown = crown))
}

/** A kitchen on visible metal legs: no plinth, the legs priced as metal ones. */
fun metalLegs(f: Furniture) = f.kind == "kitchen" && f.look?.legs == true

/** A kitchen's waterfall ends: an island's two, a peninsula's one (none without an island). */
fun waterfallEnds(f: Furniture): Int =
    if (f.kind != "kitchen" || f.look?.waterfall != true || islandLen(f) <= 0) 0 else if (f.layout == "P") 1 else 2

/* ---------------- a preset ---------------- */

/**
 * [f] set to preset [id]: the fronts' boards (the upper ones for a two-tone kitchen or hung boxes), the handles, the
 * look; a kitchen's worktop, backsplash (600 high when it had none) and crown. [fresh] (a new piece): a sliding
 * wardrobe's middle door gets the mirror too, as the mockup shows it. The extras (fluted glass, waterfall, metal legs,
 * the slim worktop) are never a preset's; LED and a bed's wall panel stay as they were.
 */
fun withPreset(f: Furniture, id: String, fresh: Boolean = false): Furniture {
    val p = designPreset(id) ?: return f
    val low = boardFor(if (p.two) p.low else p.up, p.finish, p.style)
    val up = if (p.two) boardFor(p.up, p.finish, p.style) else null
    val kitchen = f.kind == "kitchen"
    val old = f.look ?: Look()
    var g = f.copy(
        mats = f.mats.copy(front = low, frontUp = up,
            top = if (kitchen) worktopFor(p.top, if (p.top == "wood") p.accent else p.stone) else f.mats.top,
            splash = if (kitchen) splashFor(p.splash) else f.mats.splash),
        look = old.copy(preset = p.id, style = p.style, finish = p.finish, hcol = p.hcol, legs = false, fglass = false, waterfall = false,
            mirror = p.mirror, fabric = p.fabric, head = p.head, accent = "wd_" + p.accent)
    )
    g = withHandleType(g, p.handle)
    // the crown is a kitchen's (a wardrobe's height is its own size)
    if (kitchen) g = withCrown(g, if (p.crown == "none") "" else p.crown)
    if (kitchen && (g.kx?.splash ?: 0) == 0) g = g.copy(kx = (g.kx ?: KExtras()).copy(splash = K_SPLASH))
    if (fresh) g = g.copy(modules = g.modules.map { m ->
        val sl = m.slide ?: return@map m
        val n = sl.n.coerceIn(2, 4)
        if ((0 until n).any { sl.panel(it) != "ldsp" }) m else m.copy(slide = sl.copy(panels = List(n) { if (it in middleDoors(n)) "mirror" else "ldsp" }))
    })
    return g
}

/** The preset a piece shows as chosen: the one it was set to, unless something was changed since. */
fun presetOf(f: Furniture): String = f.look?.preset ?: ""

/** [f] with its look changed by [fn]; it is no longer its preset. */
fun withLook(f: Furniture, fn: (Look) -> Look): Furniture = f.copy(look = fn(f.look ?: Look()).copy(preset = ""))

/** The middle door(s) of [n] sliding doors (the mockup's mirror door): the second of two or three, the two inner ones of four. */
fun middleDoors(n: Int): Set<Int> = if (n >= 4) setOf(1, 2) else setOf(1)

/** What a sliding wardrobe's middle door is filled with: "mirror", "glass" (lacobel) or "ldsp"; null without sliding doors. */
fun middleFill(f: Furniture): String? = f.modules.firstOrNull { it.slide != null }?.slide?.let { sl -> sl.panel(middleDoors(sl.n.coerceIn(2, 4)).first()) }

/** [f] with its sliding doors' middle door(s) filled with [fill] ("mirror", "glass" lacobel, "ldsp"). */
fun withMiddleFill(f: Furniture, fill: String): Furniture = f.copy(modules = f.modules.map { m ->
    val sl = m.slide ?: return@map m
    val n = sl.n.coerceIn(2, 4)
    m.copy(slide = sl.copy(panels = List(n) { if (it in middleDoors(n)) fill else sl.panel(it) }))
})

/* ---------------- what the 3D draws ---------------- */

/**
 * A surface as the 3D draws it: [rgb], [finish] ("gloss", "matte", "wood", "stone", "glass", "mirror", "metal",
 * "fabric", "velvet", "led"), the texture [tex] (TEX_IDS; null: plain colour), [grain] along the part's length, the
 * board [mat] it is cut from (null: not a board), and for fronts their [style] (flat, shaker, fluted).
 */
data class Surface(val rgb: String, val finish: String, val tex: String? = null, val grain: Boolean = false, val mat: String? = null, val style: String = "flat")

/** A board's surface: an enamel board shows the look's finish; a plain board (no finish set) is matte. */
private fun boardSurface(id: String, mats: List<Mat>, look: Look?, style: String = "flat"): Surface {
    val m = mats.firstOrNull { it.id == id } ?: MAT_PRESETS.firstOrNull { it.id == id }
    val fin = when {
        m == null -> "matte"
        id.startsWith("en_") -> look?.finish?.takeIf { it == "gloss" || it == "matte" } ?: "matte"
        m.finish.isNotEmpty() -> m.finish
        else -> "matte"
    }
    return Surface(m?.rgb ?: "#CDBFAE", fin, m?.tex, m?.grain ?: false, id, style)
}

/**
 * What the 3D draws [part] of box [m] of [f] with ([m] null: the piece as a whole). Parts:
 *  - "front" the box's doors and drawers (the upper fronts' board for a kitchen's wall units); "frontUp", "frontLow"
 *    a two-tone piece's upper and lower fronts by name (a sliding door's panel above and below its split);
 *  - "carcass", "back", "worktop", "splash", "plinth" (the lower fronts' board), "accent" (wood; the carcass without one);
 *  - "handle", "gola", "legs", "frame" (sliding doors' and glass doors' profiles) in the handle colour;
 *  - "mirror" in its tint; "glass" (fluted when [Look.fglass]); "fabric" a bed's; "led".
 * A piece without a look (made before 25 Oct 2026) gets the colours it had, flat and matte, the handles grey.
 * [mats] the workshop's list (a board missing there is looked up in the presets).
 */
fun lookOf(f: Furniture, m: Module?, part: String, mats: List<Mat> = MAT_PRESETS): Surface {
    val l = f.look
    val style = l?.style ?: "flat"
    fun metal(): Surface = when (val c = l?.hcol ?: "") {
        "" -> Surface("#4B5563", "metal")
        "black" -> Surface(HANDLE_RGB.getValue("black"), "matte")
        else -> Surface(HANDLE_RGB[c] ?: "#4B5563", "metal")
    }
    return when (part) {
        "front" -> boardSurface(frontOf(f, m), mats, l, style)
        "frontUp" -> boardSurface(f.mats.frontUp ?: f.mats.front, mats, l, style)
        "frontLow", "plinth" -> boardSurface(f.mats.front, mats, l, if (part == "plinth") "flat" else style)
        "back" -> boardSurface(f.mats.back, mats, l)
        "worktop" -> boardSurface(worktopOf(f), mats, l)
        "splash" -> splashOf(f, mats)?.let { boardSurface(it.id, mats, l) } ?: Surface("#E8E2D8", "matte")
        "accent" -> l?.accent?.takeIf { it.isNotEmpty() }?.let { boardSurface(it, mats, l) } ?: boardSurface(f.mats.carcass, mats, l)
        "handle", "legs", "frame" -> metal()
        "gola" -> if (l?.hcol == "black" || l?.hcol.isNullOrEmpty()) Surface("#232427", "metal") else Surface("#BFC3C8", "metal")
        "mirror" -> Surface(MIRROR_RGB[l?.mirror?.takeIf { it in MIRROR_RGB } ?: "silver"]!!, "mirror")
        "glass" -> Surface("#F2F7F6", "glass", if (l?.fglass == true) "fluted_glass" else null)
        "fabric" -> LOOK_FABRICS.firstOrNull { it.key == l?.fabric }?.let { Surface(it.rgb, if (it.velvet) "velvet" else "fabric", if (it.velvet) "velvet" else if (it.key == "cream") "boucle" else "fabric") }
            ?: Surface("#E2D9CB", "fabric", "boucle")
        "led" -> Surface("#FFD39A", "led")
        else -> boardSurface(f.mats.carcass, mats, l)
    }
}

/* ---------------- hardware and prices ---------------- */

/** The fronts a front style is priced on: doors, drawer faces and appliance panels. */
private val STYLED = setOf("fp.door", "fp.dFace", "fp.panel")

/**
 * The look's own hardware of [f] (kinds counted like the modules', metre kinds in mm, area kinds in mm²): a milled or
 * fluted front style by the m² of its fronts, a kitchen's row of units to the ceiling by the metre of its wall units,
 * the waterfall ends, a wardrobe's LED with door sensors, a bed's upholstered headboard and soft wall panel. The swaps
 * (a Gola profile for the handles, metal legs, tinted mirror, fluted glass) are in [lookSwap].
 */
fun lookHardware(f: Furniture, ws0: Workshop): Map<String, Int> {
    val l = f.look ?: return emptyMap()
    val ws = wsOf(f, ws0)
    val n = LinkedHashMap<String, Int>()
    fun add(k: String, v: Int) { if (v > 0) n[k] = (n[k] ?: 0) + v }
    if (l.style == "shaker" || l.style == "fluted") {
        val mm2 = f.modules.sumOf { m -> partsOf(m, ws).filter { it.role == "front" && it.key in STYLED }.sumOf { it.L.toLong() * it.W * it.qty } }
        add(if (l.style == "shaker") "frontShaker" else "frontFluted", mm2.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
    }
    if (f.kind == "kitchen" && l.crown == "ceiling") add("ceilUnit", wallUnitsMm(f))
    add("waterfall", waterfallEnds(f))
    if (f.kind == "wardrobe" && l.led) f.modules.filter { it.type == "wardrobe" && !it.led }.forEach { m ->
        add("led", m.w - 2 * ws.t); add("ledPsu", 1)
        add("ledSensor", m.slide?.n?.coerceIn(2, 4) ?: m.sections.count { it.fronts.kind == "door" }.coerceAtLeast(1))
    }
    f.modules.filter { it.type == "bed" }.forEach { m ->
        val hb = maxOf((m.opt ?: Opt()).hb, m.h + 100)
        if (l.head.isNotEmpty()) add(if (l.head == "tufted") "headTufted" else "headSoft", m.w * (hb - m.h))
        if (l.panel) add("softPanel", (m.w + 800) * 1300)
        // the LED strip along the wall panel's top, washing the wall over it (geo/Items3D.kt)
        if (l.panel && l.led) { add("led", m.w + 800); add("ledPsu", 1) }
    }
    return n
}

/**
 * Box [m]'s hardware [h] as [f]'s look changes it: a kitchen's Gola profile instead of handles (a channel along each
 * base unit, one a drawer, two on a tall unit; the wall units open by a push latch), metal legs instead of the hidden
 * ones, the mirror in its tint, the fluted glass over the glass doors.
 */
fun lookSwap(f: Furniture, m: Module, h: MutableMap<String, Int>, edge: Boolean) {
    fun add(k: String, v: Int) { if (v > 0) h[k] = (h[k] ?: 0) + v }
    if (f.kind == "kitchen" && f.handle == GOLA) {
        val k = h.remove("handle") ?: 0
        if (k > 0) {
            if (m.type == "wall" || isUpper(m)) { if (!edge) add("push", k) }
            else add("gola", m.w * when { m.fronts.kind == "drawer" -> k; m.type == "tall" -> 2; else -> 1 })
        }
    }
    val l = f.look ?: return
    if (metalLegs(f)) h.remove("leg")?.let { add("legMetal", it) }
    if (l.mirror == "bronze" || l.mirror == "graphite") h.remove("mirror")?.let { add(if (l.mirror == "bronze") "mirrorBronze" else "mirrorGraphite", it) }
    if (l.fglass) add("fglass", h["glassDoor"] ?: 0)
}

/**
 * The handle each front with one takes on [f] with long verticals ([LONG_V]): a door 1400 mm high or more takes the
 * 1024, a door from 700 the 640, a drawer, a shorter door or a dishwasher's front the 320. In the order the hardware
 * counts them, one id a handle.
 */
fun longHandleIds(f: Furniture, ws0: Workshop): List<String> {
    val ws = wsOf(f, ws0)
    val out = ArrayList<String>()
    fun door(h: Int) = when { h >= 1400 -> "handle1024"; h >= 700 -> "handle640"; else -> "handleLong" }
    f.modules.filter { takesHandles(it) }.forEach { m ->
        handleFronts(m).filter { hasHandle(m, it.key) }.forEach { fr ->
            out += when {
                fr.drawer || m.type == "gap" -> "handleLong"
                fr.sec >= 0 -> {
                    val s = m.sections.getOrNull(fr.sec)
                    val j = fr.key.substringAfter(":f").toIntOrNull() ?: 0
                    s?.let { frontSizes(it.fronts, frontW(it), m.h - wardBase(m), ws).getOrNull(j)?.first }?.let(::door) ?: "handleLong"
                }
                else -> frontSizes(m.fronts, m.w, m.h, ws).getOrNull(fr.key.removePrefix("f").toIntOrNull() ?: 0)?.first?.let(::door) ?: "handleLong"
            }
        }
    }
    return out
}
