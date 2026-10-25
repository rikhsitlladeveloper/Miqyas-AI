package uz.metrx.app.geo

/*
 * How a surface looks in the lit 3D (modern 3D part 1, 25 Oct 2026): one description for every board, worktop,
 * metal, glass and light, the materials of the approved mockup (scratchpad modern3d mats()). Pure data: ui/three
 * turns a Look into a Filament material. Colours are sRGB numbers, like the boards' rgb.
 */

/**
 * A surface: base colour [rgb]; [rough] 0 mirror-smooth to 1 chalk; [metal] 0 or 1 (in between for brushed or
 * painted metal); [clear] a lacquer's coat (gloss fronts, polished stone), drawn as a sharper, stronger highlight;
 * [tex] a picture from [TEXTURES] laid over it ([tint] true: the picture is grey and takes [rgb] as its colour,
 * fabrics; false: the picture is the colour, wood and stone decors); [emissive] above 0 glows (LED strips);
 * [alpha] below 1 is see-through (glass).
 */
data class Look(
    val rgb: Int,
    val rough: Float = .6f,
    val metal: Float = 0f,
    val clear: Float = 0f,
    val tex: String? = null,
    val tint: Boolean = false,
    val emissive: Float = 0f,
    val alpha: Float = 1f,
    /** How much a non-metal reflects head-on, 0..1 (0.5 = 4 %, most paints and boards). */
    val reflect: Float = .5f
) {
    /** Metres one repeat of the picture covers along the grain and across it. */
    val uvScale: Double get() = tex?.let { TEXTURES[it]?.metres } ?: 1.0
    val uvScaleV: Double get() = tex?.let { TEXTURES[it]?.metresV } ?: uvScale

    /** The look on a weak phone (mockup "Yengil"): mirrors and chrome without a sharp reflection to show, so duller. */
    fun light(): Look = if (metal > .5f) copy(metal = .4f, rough = maxOf(.3f, rough)) else if (clear > 0f) copy(rough = maxOf(rough, .22f), clear = 0f) else this
}

/**
 * A texture: the picture [file] in app/src/main/assets/tex/ (512/ and 256/ sizes, see SOURCES.md), the metres it
 * covers along u and v, its average colour [avg]. [tint] (sRGB) recolours the picture so its average becomes that
 * colour (a darker oak from a light one); null: as drawn. [fit] a picture laid once over its panel from the panel's
 * corner (a printed skinali), not at a random offset like the grain of boards.
 */
class TexInfo(val metres: Double, val avg: Int, val metresV: Double = metres, val file: String = "", val tint: Int? = null, val fit: Boolean = false)

/** The bundled pictures, each under its own file name. Wood has its grain along the picture's width (u). */
private val FILES: Map<String, TexInfo> = mapOf(
    "oak_halifax" to TexInfo(1.2, 0xA37A53),
    "oak_craft" to TexInfo(1.0, 0xBF8E56),
    "walnut" to TexInfo(1.0, 0x644431),
    "wenge" to TexInfo(1.0, 0x3D2C23),
    "marble_white" to TexInfo(1.5, 0xE5E2DD),
    "travertine" to TexInfo(1.5, 0xDFD1B7),
    "stone_dark" to TexInfo(1.5, 0x2F2E2C),
    "fabric_boucle" to TexInfo(.5, 0xD5D5D5),
    "fabric_weave" to TexInfo(.35, 0xD5D5D5),
    "floor_planks" to TexInfo(2.08, 0xB88C61),
    "tile_subway" to TexInfo(.6, 0xEBEAE7),
    // our own drawing (SOURCES.md): 4:1, tiles left to right, laid from the panel's bottom corner
    "skinali_print" to TexInfo(2.4, 0x9AA7B8, .6, fit = true)
).mapValues { (k, v) -> TexInfo(v.metres, v.avg, v.metresV, k, v.tint, v.fit) }

/**
 * The decors' texture ids (furniture Decors.kt, TEX_IDS) on the bundled pictures: the same picture for several decors,
 * recoloured where the decor is another shade. "fluted" and "fluted_glass" are drawn as geometry, not pictures. The
 * iPhone app reads the same table (keep the two alike).
 */
private val ALIASES: Map<String, Pair<String, Int?>> = mapOf(
    "oak_light" to ("oak_halifax" to null),
    "oak_tobacco" to ("oak_halifax" to 0x7A5A40),   // Halifax tobacco: the same oak, darker and warmer
    "oak_golden" to ("oak_craft" to null),
    "oak_dark" to ("wenge" to 0x5A3F2E),           // Charleston dark oak: the dark veneer, a little lighter
    "onyx_beige" to ("travertine" to 0xE8DBC2),
    "tile_white" to ("tile_subway" to null),
    "boucle" to ("fabric_boucle" to null),           // fabrics are grey: the Look's colour tints them (Look.tint)
    "velvet" to ("fabric_weave" to null),
    "fabric" to ("fabric_weave" to null)
)

/** Every texture id the 3D can be given (the pictures' own and the decors'), each on its picture file. */
val TEXTURES: Map<String, TexInfo> = FILES + ALIASES.mapValues { (_, a) ->
    val f = FILES.getValue(a.first); TexInfo(f.metres, a.second ?: f.avg, f.metresV, f.file, a.second, f.fit)
}

/** The picture files bundled (each in 512/ and 256/). */
val TEX_FILES: Set<String> get() = TEXTURES.values.map { it.file }.toSet()

/** The looks the furniture uses that are not one of the workshop's boards (mockup mats()). */
object Looks {
    /** A board (LDSP, MDF) in colour [rgb], or a decor picture [tex]; [finish] "matte", "satin" or "gloss". */
    fun board(rgb: Int, tex: String? = null, finish: String = "matte"): Look = when (finish) {
        // acrylic / high-gloss MDF: a sharp lacquer highlight (mockup: roughness .06 + clearcoat)
        "gloss" -> Look(rgb, rough = .1f, clear = 1f, tex = tex, reflect = .62f)
        "satin" -> Look(rgb, rough = .42f, tex = tex, reflect = .5f)
        // LDSP and soft-touch: matte (mockup .86 for painted, .55–.6 for wood decors)
        else -> Look(rgb, rough = if (tex != null) .58f else .8f, tex = tex, reflect = .42f)
    }

    /** A workshop material of [kind] (board, back, worktop, splash) in colour [rgb] with decor picture [tex]. */
    fun of(kind: String, rgb: Int, tex: String? = null, finish: String = "matte"): Look = when (kind) {
        "worktop" -> worktop(rgb, tex)
        "splash" -> if (tex != null) Look(rgb, rough = .2f, clear = .6f, tex = tex, reflect = .55f) else Look(rgb, rough = .3f, reflect = .5f)
        "back" -> Look(rgb, rough = .85f, tex = tex)
        else -> board(rgb, tex, finish)
    }

    /** A worktop: stone decors polished, plain colours a satin laminate. */
    fun worktop(rgb: Int, tex: String? = null): Look =
        if (tex != null && tex.startsWith("oak") || tex == "walnut" || tex == "wenge") Look(rgb, rough = .45f, tex = tex, reflect = .45f)
        else if (tex != null) Look(rgb, rough = .18f, clear = .6f, tex = tex, reflect = .55f)
        else Look(rgb, rough = .38f, reflect = .5f)

    /** Brushed steel: sinks, rails, frames, legs (mockup steel #CDD0D4, .24). */
    val steel = Look(0xCDD0D4, rough = .34f, metal = 1f)
    /** Handles: dark painted metal (the app's handle colour, a soft sheen). */
    val handle = Look(0x3A3F47, rough = .4f, metal = .6f)
    /**
     * A mirror: silver, nearly smooth. Partly metal (.4 since part 5; .55 read grey on the wardrobes): a full one shows only the studio's floor from above and reads as a
     * dark panel; this way it stays a bright silver with the room's light running over it.
     */
    val mirror = Look(0xD3DCE4, rough = .05f, metal = .4f, reflect = .9f)
    /** Lakobel, the painted glass of sliding-door panels: opaque, glossy. */
    val lacobel = Look(0x8FA9C4, rough = .06f, clear = 1f, reflect = .7f)
    /** Clear glass (vitrina doors, glass shelves): faint green-white, see-through. */
    val clearGlass = Look(0xEAF2EF, rough = .03f, alpha = .22f, reflect = .7f)
    /** Black appliance glass (hob, oven door). */
    val blackGlass = Look(0x16181C, rough = .06f, clear = 1f, reflect = .6f)
    /** White enamel (fridge, basin). */
    val enamel = Look(0xEEF0F2, rough = .25f, clear = .5f, reflect = .55f)
    /** A mattress: woven fabric, off-white. */
    val mattress = Look(0xF1EFEA, rough = .92f, tex = "fabric_weave", tint = true, reflect = .3f)
    /** A bed's slats: birch plywood. */
    val lamel = Look(0xD9C29A, rough = .6f)
    /** A LED strip, lit. */
    val led = Look(0xFFE7B8, rough = .4f, emissive = 2.2f)
    /** What the parts list lights up. */
    val hi = Look(0xF59E0B, rough = .5f, emissive = .35f)
    /**
     * The look of a design surface (furniture Look.kt lookOf: colour, finish, texture) as [kind] uses it: "board" (fronts,
     * carcass), "worktop", "splash", "hardware" (handles, the Gola profile, frames, legs), "glass".
     */
    fun surface(rgb: Int, finish: String, tex: String?, kind: String = "board"): Look = when {
        kind == "hardware" -> if (finish == "metal") metalOf(rgb) else Look(rgb, rough = .42f, metal = .55f)
        finish == "mirror" -> if (rgb == 0xBCC0C4) mirror else mirror.copy(rgb = rgb)
        kind == "glass" || (finish == "glass" && kind == "board") -> if (tex == "fluted_glass") flutedGlass else clearGlass
        finish == "led" -> led.copy(rgb = rgb)
        finish == "fabric" || finish == "velvet" -> Look(rgb, rough = if (finish == "velvet") .8f else .93f, tex = tex, tint = true, reflect = if (finish == "velvet") .45f else .3f)
        kind == "worktop" -> worktop(rgb, tex)
        // skinali (painted or printed glass) mirror-smooth; tiles glazed; an older panel as before
        kind == "splash" -> when (finish) {
            "glass" -> Look(rgb, rough = .04f, clear = 1f, tex = tex, reflect = .6f)
            "gloss" -> Look(rgb, rough = .22f, clear = .7f, tex = tex, reflect = .55f)
            else -> of("splash", rgb, tex)
        }
        finish == "stone" -> worktop(rgb, tex)
        // wood decors (LDSP) a soft matte with their grain
        finish == "wood" -> Look(rgb, rough = .55f, tex = tex, reflect = .42f)
        else -> board(rgb, tex, finish)
    }

    /** A metal in colour [rgb]: chrome, gold and brass polished to their own degree, dark metals painted. */
    fun metalOf(rgb: Int): Look = when (rgb) {
        0xE3E6EA -> Look(0xECEEF1, rough = .08f, metal = 1f)
        0xDDB466 -> Look(0xE0B768, rough = .2f, metal = 1f)
        0xB9975B -> Look(0xB9975B, rough = .33f, metal = 1f)
        0x4B5563 -> handle
        else -> if (((rgb shr 16) and 255) + ((rgb shr 8) and 255) + (rgb and 255) < 3 * 0x50) Look(rgb, rough = .45f, metal = .5f) else Look(rgb, rough = .3f, metal = 1f)
    }

    /** Polished chrome: a wardrobe's hanging rails (mockup steel rails, brighter). */
    val chrome = Look(0xECEEF1, rough = .08f, metal = 1f)
    /** A LED strip's aluminium channel while it is off (a wardrobe's, its doors shut: mockup #D3D5D8). */
    val ledOff = Look(0xD3D5D8, rough = .4f, metal = .2f)
    /** A glass shelf: thicker-looking than a door's glass, its green edge showing (mockup shelfG #D6EAE3, .4). */
    val shelfGlass = Look(0xD6EAE3, rough = .04f, alpha = .4f, reflect = .7f)
    /** A light streak across a mirror ([alpha] see-through white, unlit: Furniture3D sheen). */
    fun sheen(alpha: Float) = Look(0xFFFFFF, rough = 1f, emissive = 1.05f, alpha = alpha)
    /** Fluted (reeded) glass: frosted by its ribs, half see-through (mockup fglass). */
    val flutedGlass = Look(0xEAF2F0, rough = .3f, alpha = .55f, reflect = .6f)
    /** An oven's and a microwave's window: smoked glass a shade lighter than the door. */
    val ovenWindow = Look(0x1B1E24, rough = .04f, clear = 1f, reflect = .65f)
    /** An appliance's lit display (orange digits). */
    val display = Look(0xFF9A3C, rough = .5f, emissive = 1.3f)
    /** The rings printed on a black glass hob. */
    val hobRing = Look(0x6B7079, rough = .25f, clear = .4f, reflect = .5f)
    /** A granite-composite sink, dark. */
    val granite = Look(0x2A2B2E, rough = .55f, reflect = .45f)
    /** Brushed steel of a sink bowl. */
    val sinkSteel = Look(0xBFC3C7, rough = .32f, metal = 1f)
    /** The soft warm light a LED strip throws on the wall and worktop under it, see-through [alpha] (mockup glow). */
    fun glow(alpha: Float) = Look(0xFFC98A, rough = 1f, emissive = 1.3f, alpha = alpha)

    /** The room's floor under furniture: oak planks; walls: matte paint (mockup #EEEAE3, .95). */
    fun floor(rgb: Int): Look = if (rgb == 0xC49A6C) Look(rgb, rough = .5f, tex = "floor_planks", reflect = .45f) else Look(rgb, rough = .7f)
    fun wall(rgb: Int, alpha: Float = 1f): Look = Look(rgb, rough = .95f, alpha = alpha, reflect = .35f)
    /** Anything else in its plain colour (doors and windows of the room, a tiler's tiles): a soft satin. */
    fun plain(rgb: Int, alpha: Float = 1f): Look = Look(rgb, rough = .6f, alpha = alpha)
}

/* ---------------- texture coordinates ---------------- */

/** u (along [ua]) and v (along [va]) of each of [pts], in metres from [o] plus [off]. */
internal fun uvOf(pts: List<V3>, o: V3, ua: V3, va: V3, offU: Double, offV: Double): DoubleArray {
    val out = DoubleArray(pts.size * 2)
    pts.forEachIndexed { i, p -> val d = p - o; out[2 * i] = d.dot(ua) + offU; out[2 * i + 1] = d.dot(va) + offV }
    return out
}

/**
 * Texture coordinates for a flat face without its own (walls, floors, tiles): its plane's two other axes, metres.
 * A floor's run along x and z, a wall's along itself and up.
 */
fun planarUv(f: Face): DoubleArray {
    val n = f.n; val ax = kotlin.math.abs(n.x); val ay = kotlin.math.abs(n.y); val az = kotlin.math.abs(n.z)
    val out = DoubleArray(f.pts.size * 2)
    f.pts.forEachIndexed { i, p ->
        val (u, v) = when {
            ay >= ax && ay >= az -> p.x to p.z
            ax >= az -> p.z to p.y
            else -> p.x to p.y
        }
        out[2 * i] = u; out[2 * i + 1] = v
    }
    return out
}

/** A box's own offset into its picture (metres), so neighbouring boards do not show the same grain. */
internal fun grainOffset(o: V3): Pair<Double, Double> {
    var h = 2166136261L.toInt()
    for (k in listOf(o.x, o.y, o.z)) { h = (h xor (k * 1000).toInt()) * 16777619 }
    val a = ((h ushr 8) and 0xFFFF) / 65535.0; val b = ((h ushr 16) * 31 and 0xFFFF) / 65535.0
    return a * 2.0 to b * 2.0
}
