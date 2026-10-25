package uz.metrx.app.furniture

/*
 * The board decors the design presets use (modern 3D part 2, 25 Oct 2026): the approved mockup's colours, woods and
 * stones (scratchpad modern3d/modern-3d.html COL, WOOD, STONE) as the workshop's material presets, with local names
 * (design/furniture/uz-market-research.md, section 3), a finish and a texture id for the 3D, and a price per m² or per
 * running metre. Kept in a file of their own: MAT_PRESETS (Workshop.kt) adds them, and nothing here reads it back.
 * Every price is a sample for the makers to replace (Profile → Materials).
 */

/** A front colour of the presets: its key, the mockup's colour, and the names' strings key (lk.c.*). */
data class LookColour(val key: String, val rgb: String)

/** The mockup's colour fronts, in its order (COL). */
val LOOK_COLOURS = listOf(
    LookColour("white", "#F2F2EF"),
    LookColour("cream", "#E9DEC8"),       // AGT Sahara Cream 3019
    LookColour("ivory", "#EEE5D2"),
    LookColour("lgrey", "#C5C8CA"),       // AGT Dolphin Grey 3023
    LookColour("cashmere", "#CDBFAE"),    // Ultradecor 5981 Кашемир
    LookColour("graphite", "#41454C"),
    LookColour("black", "#19191B"),
    LookColour("olive", "#6A7152"),
    LookColour("navy", "#25334E")
)

/** A wood decor: key, its average colour, the texture id. */
data class LookWood(val key: String, val rgb: String, val tex: String)

/** Wood decors: the mockup's three (WOOD) and Halifax tobacco, dark oak and wenge from the research. */
val LOOK_WOODS = listOf(
    LookWood("halifax", "#A27A53", "oak_light"),     // Egger H1180 Halifax natural
    LookWood("tobacco", "#7A5A40", "oak_tobacco"),   // Egger H1181 Halifax tobacco
    LookWood("craft", "#BC8C55", "oak_golden"),      // Ultradecor K003 Craft golden oak
    LookWood("dark", "#5A3F2E", "oak_dark"),         // Egger H3154 Charleston dark brown
    LookWood("walnut", "#634330", "walnut"),
    LookWood("wenge", "#3B2A22", "wenge")
)

/** Stone-look decors (STONE): key, colour, texture id. */
val LOOK_STONES = listOf(
    LookWood("marble", "#F1EFEB", "marble_white"),
    LookWood("onyx", "#E8DBC2", "onyx_beige"),
    LookWood("dark", "#26282B", "stone_dark")
)

/** Upholstery fabrics (FAB): key, colour; [velvet] a velvet's sheen. */
data class LookFabric(val key: String, val rgb: String, val velvet: Boolean = false)

val LOOK_FABRICS = listOf(
    LookFabric("cream", "#E2D9CB"),        // boucle
    LookFabric("grey", "#9C9FA3"),
    LookFabric("olive", "#646C48", true),
    LookFabric("navy", "#2B3956", true),
    LookFabric("mocha", "#86695A")
)

/** Handle and frame colours (HCOLHEX). */
val HANDLE_RGB = linkedMapOf("black" to "#1E1F22", "brass" to "#B9975B", "gold" to "#DDB466", "chrome" to "#E3E6EA")

/** Mirror tints (MIRR): the 3D colour. */
val MIRROR_RGB = linkedMapOf("silver" to "#BCC0C4", "bronze" to "#C2A487", "graphite" to "#9A9DA1")

/** The colour fronts' families: id prefix → (finish, thickness, sheet length × width, price per m², name in Uzbek). */
private data class Family(val prefix: String, val finish: String, val t: Int, val l: Int, val w: Int, val m2: String, val name: String)

/*
 * Prices per m² (research section 2, Fronts):
 *  - acrylic gloss: AGT 2800 × 1220 × 18 at 1 378 600 a sheet (Eman) = 403 600 a m²;
 *  - soft-touch matte: Kastamonu Evosoft 1220 × 2800 at about 1,56 M a sheet (KS Lux) = 456 700 a m²;
 *  - MDF enamel (any RAL, millable): Ustabor 150–350 k, Lux Home Mebel 250–400 k a m²;
 *  - wood-decor LDSP: Egger 18 at 620–990 k a 2800 × 2070 sheet (Eman) = 107–171 k a m²; local decors cheaper.
 */
private val FAMILIES = listOf(
    Family("ag_", "gloss", 18, 2800, 1220, "400000", "Akril glyanets"),
    Family("sm_", "matte", 18, 2800, 1220, "450000", "Soft-touch mat"),
    Family("en_", "matte", 19, 2800, 2070, "280000", "MDF emal")
)

private val COLOUR_UZ = mapOf("white" to "Oq", "cream" to "Krem (Sahara Cream)", "ivory" to "Fil suyagi", "lgrey" to "Och kulrang (Dolphin Grey)",
    "cashmere" to "Kashmir", "graphite" to "Grafit", "black" to "Qora", "olive" to "Zaytun", "navy" to "To‘q ko‘k")

private val WOOD_UZ = mapOf("halifax" to "Egger H1180 · Halifax tabiiy dub", "tobacco" to "Egger H1181 · Halifax tamaki dub",
    "craft" to "Ultradecor K003 · Craft oltin dub", "dark" to "Egger H3154 · Charleston to‘q dub", "walnut" to "Yong‘oq (shokolad)", "wenge" to "Venge")

private val WOOD_M2 = mapOf("halifax" to "150000", "tobacco" to "150000", "craft" to "130000", "dark" to "150000", "walnut" to "110000", "wenge" to "110000")

/** The decor presets: 27 colour fronts, 6 wood decors, 8 worktops and 3 backsplashes. */
val DECOR_PRESETS: List<Mat> =
    FAMILIES.flatMap { fm -> LOOK_COLOURS.map { c ->
        Mat(fm.prefix + c.key, "board", fm.name + " · " + COLOUR_UZ.getValue(c.key), fm.t, fm.l, fm.w, fm.m2, rgb = c.rgb, preset = true, finish = fm.finish, per = "m2")
    } } +
    LOOK_WOODS.map { w -> Mat("wd_" + w.key, "board", WOOD_UZ.getValue(w.key), 18, price = WOOD_M2.getValue(w.key), grain = true, rgb = w.rgb, preset = true,
        finish = "wood", tex = w.tex, per = "m2") } +
    listOf(
        // 38 mm stone-look HPL on chipboard, by the running metre (the plain wt38 is 360 000); stone-look decors at Eman ("Мрамор Персия", "Оникс бежевый")
        Mat("wt38m", "worktop", "Stoleshnitsa 38 · Oq marmar (HPL)", 38, 4100, 600, "420000", rgb = "#F1EFEB", preset = true, finish = "stone", tex = "marble_white"),
        Mat("wt38o", "worktop", "Stoleshnitsa 38 · Oniks bej (HPL)", 38, 4100, 600, "420000", rgb = "#E8DBC2", preset = true, finish = "stone", tex = "onyx_beige"),
        Mat("wt38d", "worktop", "Stoleshnitsa 38 · Qora tosh (HPL)", 38, 4100, 600, "420000", rgb = "#26282B", preset = true, finish = "stone", tex = "stone_dark"),
        Mat("wt38c", "worktop", "Stoleshnitsa 38 · Craft oltin dub", 38, 4100, 600, "400000", grain = true, rgb = "#BC8C55", preset = true, finish = "wood", tex = "oak_golden"),
        Mat("wt38h", "worktop", "Stoleshnitsa 38 · Halifax dub", 38, 4100, 600, "400000", grain = true, rgb = "#A27A53", preset = true, finish = "wood", tex = "oak_light"),
        // the slim 20 mm stone (an extra): quartz from 2,15 M a running metre (Service-Eco)
        Mat("wt20m", "worktop", "Stoleshnitsa 20 · kvars, oq marmar", 20, 3000, 600, "2150000", rgb = "#F1EFEB", preset = true, finish = "stone", tex = "marble_white"),
        Mat("wt20o", "worktop", "Stoleshnitsa 20 · kvars, oniks bej", 20, 3000, 600, "2150000", rgb = "#E8DBC2", preset = true, finish = "stone", tex = "onyx_beige"),
        Mat("wt20d", "worktop", "Stoleshnitsa 20 · kvars, qora tosh", 20, 3000, 600, "2150000", rgb = "#26282B", preset = true, finish = "stone", tex = "stone_dark"),
        // backsplashes by the m² (Lux Home Mebel, Apr 2026): glass (skinali) 250–500 k, ceramic tile 120–350 k
        Mat("skGlass", "splash", "Skinali · oddiy shisha", 6, 3000, 600, "380000", rgb = "#ECE9E3", preset = true, finish = "glass", per = "m2"),
        Mat("skPrint", "splash", "Skinali · rasmli", 6, 3000, 600, "480000", rgb = "#C9D6E2", preset = true, finish = "glass", tex = "skinali_print", per = "m2"),
        Mat("spTile", "splash", "Kafel (fartuk)", 8, 600, 300, "230000", rgb = "#F1EFEA", preset = true, finish = "gloss", tex = "tile_white", per = "m2")
    )
