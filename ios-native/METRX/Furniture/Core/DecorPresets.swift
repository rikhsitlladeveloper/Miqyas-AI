import Foundation

/*
 * The board decors the design presets use (modern 3D part 2, 25 Oct 2026; Android furniture/Decors.kt): the approved
 * mockup's colours, woods and stones as the workshop's material presets, with local names
 * (design/furniture/uz-market-research.md, section 3), a finish and a texture id for the 3D, and a price per m² or per
 * running metre. Kept in a file of their own: MAT_PRESETS (Workshop.swift) adds them, and nothing here reads it back.
 * Every price is a sample for the makers to replace (Profile → Materials).
 */

/// A front colour of the presets: its key, the mockup's colour, and the names' strings key (lk.c.*).
struct LookColour: Equatable { let key: String, rgb: String }

/// The mockup's colour fronts, in its order (COL).
let LOOK_COLOURS: [LookColour] = [
    LookColour(key: "white", rgb: "#F2F2EF"),
    LookColour(key: "cream", rgb: "#E9DEC8"),       // AGT Sahara Cream 3019
    LookColour(key: "ivory", rgb: "#EEE5D2"),
    LookColour(key: "lgrey", rgb: "#C5C8CA"),       // AGT Dolphin Grey 3023
    LookColour(key: "cashmere", rgb: "#CDBFAE"),    // Ultradecor 5981 Кашемир
    LookColour(key: "graphite", rgb: "#41454C"),
    LookColour(key: "black", rgb: "#19191B"),
    LookColour(key: "olive", rgb: "#6A7152"),
    LookColour(key: "navy", rgb: "#25334E")
]

/// A wood decor: key, its average colour, the texture id.
struct LookWood: Equatable { let key: String, rgb: String, tex: String }

/// Wood decors: the mockup's three (WOOD) and Halifax tobacco, dark oak and wenge from the research.
let LOOK_WOODS: [LookWood] = [
    LookWood(key: "halifax", rgb: "#A27A53", tex: "oak_light"),     // Egger H1180 Halifax natural
    LookWood(key: "tobacco", rgb: "#7A5A40", tex: "oak_tobacco"),   // Egger H1181 Halifax tobacco
    LookWood(key: "craft", rgb: "#BC8C55", tex: "oak_golden"),      // Ultradecor K003 Craft golden oak
    LookWood(key: "dark", rgb: "#5A3F2E", tex: "oak_dark"),         // Egger H3154 Charleston dark brown
    LookWood(key: "walnut", rgb: "#634330", tex: "walnut"),
    LookWood(key: "wenge", rgb: "#3B2A22", tex: "wenge")
]

/// Stone-look decors (STONE): key, colour, texture id.
let LOOK_STONES: [LookWood] = [
    LookWood(key: "marble", rgb: "#F1EFEB", tex: "marble_white"),
    LookWood(key: "onyx", rgb: "#E8DBC2", tex: "onyx_beige"),
    LookWood(key: "dark", rgb: "#26282B", tex: "stone_dark")
]

/// Upholstery fabrics (FAB): key, colour; velvet a velvet's sheen.
struct LookFabric: Equatable { let key: String, rgb: String; var velvet = false }

let LOOK_FABRICS: [LookFabric] = [
    LookFabric(key: "cream", rgb: "#E2D9CB"),        // boucle
    LookFabric(key: "grey", rgb: "#9C9FA3"),
    LookFabric(key: "olive", rgb: "#646C48", velvet: true),
    LookFabric(key: "navy", rgb: "#2B3956", velvet: true),
    LookFabric(key: "mocha", rgb: "#86695A")
]

/// Handle and frame colours (HCOLHEX), in the order the chips show them.
let HANDLE_COLOURS = ["black", "brass", "gold", "chrome"]
let HANDLE_RGB: [String: String] = ["black": "#1E1F22", "brass": "#B9975B", "gold": "#DDB466", "chrome": "#E3E6EA"]

/// Mirror tints (MIRR): the 3D colour.
let MIRROR_TINTS = ["silver", "bronze", "graphite"]
let MIRROR_RGB: [String: String] = ["silver": "#BCC0C4", "bronze": "#C2A487", "graphite": "#9A9DA1"]

/// The colour fronts' families: id prefix → (finish, thickness, sheet length × width, price per m², name in Uzbek).
private struct DecorFamily { let prefix: String, finish: String, t: Int, l: Int, w: Int, m2: String, name: String }

/*
 * Prices per m² (research section 2, Fronts):
 *  - acrylic gloss: AGT 2800 × 1220 × 18 at 1 378 600 a sheet (Eman) = 403 600 a m²;
 *  - soft-touch matte: Kastamonu Evosoft 1220 × 2800 at about 1,56 M a sheet (KS Lux) = 456 700 a m²;
 *  - MDF enamel (any RAL, millable): Ustabor 150–350 k, Lux Home Mebel 250–400 k a m²;
 *  - wood-decor LDSP: Egger 18 at 620–990 k a 2800 × 2070 sheet (Eman) = 107–171 k a m²; local decors cheaper.
 */
private let DECOR_FAMILIES: [DecorFamily] = [
    DecorFamily(prefix: "ag_", finish: "gloss", t: 18, l: 2800, w: 1220, m2: "400000", name: "Akril glyanets"),
    DecorFamily(prefix: "sm_", finish: "matte", t: 18, l: 2800, w: 1220, m2: "450000", name: "Soft-touch mat"),
    DecorFamily(prefix: "en_", finish: "matte", t: 19, l: 2800, w: 2070, m2: "280000", name: "MDF emal")
]

private let DECOR_COLOUR_UZ: [String: String] = ["white": "Oq", "cream": "Krem (Sahara Cream)", "ivory": "Fil suyagi", "lgrey": "Och kulrang (Dolphin Grey)",
    "cashmere": "Kashmir", "graphite": "Grafit", "black": "Qora", "olive": "Zaytun", "navy": "To‘q ko‘k"]

private let DECOR_WOOD_UZ: [String: String] = ["halifax": "Egger H1180 · Halifax tabiiy dub", "tobacco": "Egger H1181 · Halifax tamaki dub",
    "craft": "Ultradecor K003 · Craft oltin dub", "dark": "Egger H3154 · Charleston to‘q dub", "walnut": "Yong‘oq (shokolad)", "wenge": "Venge"]

private let DECOR_WOOD_M2: [String: String] = ["halifax": "150000", "tobacco": "150000", "craft": "130000", "dark": "150000", "walnut": "110000", "wenge": "110000"]

private func decorFronts() -> [Mat] {
    DECOR_FAMILIES.flatMap { fm in
        LOOK_COLOURS.map { c in
            Mat(fm.prefix + c.key, "board", fm.name + " · " + (DECOR_COLOUR_UZ[c.key] ?? c.key), fm.t, l: fm.l, w: fm.w, price: fm.m2, rgb: c.rgb, preset: true,
                finish: fm.finish, per: "m2")
        }
    }
}

private func decorWoods() -> [Mat] {
    LOOK_WOODS.map { w in
        Mat("wd_" + w.key, "board", DECOR_WOOD_UZ[w.key] ?? w.key, 18, price: DECOR_WOOD_M2[w.key] ?? "", grain: true, rgb: w.rgb, preset: true,
            finish: "wood", tex: w.tex, per: "m2")
    }
}

private func decorTops() -> [Mat] {
    [
        // 38 mm stone-look HPL on chipboard, by the running metre (the plain wt38 is 360 000); stone-look decors at Eman
        Mat("wt38m", "worktop", "Stoleshnitsa 38 · Oq marmar (HPL)", 38, l: 4100, w: 600, price: "420000", rgb: "#F1EFEB", preset: true, finish: "stone", tex: "marble_white"),
        Mat("wt38o", "worktop", "Stoleshnitsa 38 · Oniks bej (HPL)", 38, l: 4100, w: 600, price: "420000", rgb: "#E8DBC2", preset: true, finish: "stone", tex: "onyx_beige"),
        Mat("wt38d", "worktop", "Stoleshnitsa 38 · Qora tosh (HPL)", 38, l: 4100, w: 600, price: "420000", rgb: "#26282B", preset: true, finish: "stone", tex: "stone_dark"),
        Mat("wt38c", "worktop", "Stoleshnitsa 38 · Craft oltin dub", 38, l: 4100, w: 600, price: "400000", grain: true, rgb: "#BC8C55", preset: true, finish: "wood", tex: "oak_golden"),
        Mat("wt38h", "worktop", "Stoleshnitsa 38 · Halifax dub", 38, l: 4100, w: 600, price: "400000", grain: true, rgb: "#A27A53", preset: true, finish: "wood", tex: "oak_light"),
        // the slim 20 mm stone (an extra): quartz from 2,15 M a running metre (Service-Eco)
        Mat("wt20m", "worktop", "Stoleshnitsa 20 · kvars, oq marmar", 20, l: 3000, w: 600, price: "2150000", rgb: "#F1EFEB", preset: true, finish: "stone", tex: "marble_white"),
        Mat("wt20o", "worktop", "Stoleshnitsa 20 · kvars, oniks bej", 20, l: 3000, w: 600, price: "2150000", rgb: "#E8DBC2", preset: true, finish: "stone", tex: "onyx_beige"),
        Mat("wt20d", "worktop", "Stoleshnitsa 20 · kvars, qora tosh", 20, l: 3000, w: 600, price: "2150000", rgb: "#26282B", preset: true, finish: "stone", tex: "stone_dark"),
        // backsplashes by the m² (Lux Home Mebel, Apr 2026): glass (skinali) 250–500 k, ceramic tile 120–350 k
        Mat("skGlass", "splash", "Skinali · oddiy shisha", 6, l: 3000, w: 600, price: "380000", rgb: "#ECE9E3", preset: true, finish: "glass", per: "m2"),
        Mat("skPrint", "splash", "Skinali · rasmli", 6, l: 3000, w: 600, price: "480000", rgb: "#C9D6E2", preset: true, finish: "glass", tex: "skinali_print", per: "m2"),
        Mat("spTile", "splash", "Kafel (fartuk)", 8, l: 600, w: 300, price: "230000", rgb: "#F1EFEA", preset: true, finish: "gloss", tex: "tile_white", per: "m2")
    ]
}

/// The decor presets: 27 colour fronts, 6 wood decors, 8 worktops and 3 backsplashes.
let DECOR_PRESETS: [Mat] = decorFronts() + decorWoods() + decorTops()
