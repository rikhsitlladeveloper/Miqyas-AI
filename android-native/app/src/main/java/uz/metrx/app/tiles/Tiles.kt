package uz.metrx.app.tiles

import kotlinx.serialization.Serializable

/*
 * The tiler's app (Kafelchi, 22 Oct 2026): tile layouts laid on a measured room's floor and walls, or on a surface typed
 * by its sizes. A layout is one pattern of one tile (and a second tile for a chessboard, a border strip or an accent
 * wall) on the surfaces ticked for it; a room may have several (the floor one, the walls another). Lengths are mm.
 * Pure Kotlin, unit-tested (TilesTest): the layout in Layout.kt, the counting in Count.kt, the 3D in Mesh.kt.
 */

/**
 * One layout. [a] × [b] is the tile, short side first (300 × 600); in the pattern its long side runs along the
 * surface ([rot] 0), up it (90) or at 45°. [pattern]: straight, brick2, brick3 (rows shifted by a half or a third),
 * diagonal, herring (herringbone), chess (two looks), border (a strip of the second tile round the floor, or a band
 * on the walls at [band]). [start]: center, corner or door, moved by hand by [ox], [oy] on the plan. [look] and
 * [look2] are ids of [LOOKS]; [a2] × [b2] the border strip's tile (0: as the main one). [roomId] null: a surface typed
 * by its sizes ([panel]). [spare], [boxM2], [boxPcs] and [price] are the advanced app's (empty: the usual ones).
 */
@Serializable
data class TileLayout(
    val id: String,
    val model: String = "",
    val place: String = "floor",
    val pattern: String = "straight",
    val a: Int = 600, val b: Int = 600,
    val joint: Int = 2,
    val start: String = "center",
    val rot: Int = 0,
    val ox: Int = 0, val oy: Int = 0,
    val look: String = "white",
    val look2: String = "graph",
    val a2: Int = 0, val b2: Int = 0,
    val accent: Boolean = false,
    val band: Int = 1200,
    val roomId: String? = null,
    val surfs: List<TSurf> = emptyList(),
    val panel: TPanel? = null,
    /** Walls: the joints start where the floor's do, so they line up at the floor. */
    val align: Boolean = true,
    /** Floors: tile skirting this high (0: none), cut from the same tile. */
    val skirt: Int = 0,
    /** Walls: corner profiles on the outside corners (window reveals, niches, columns). */
    val profiles: Boolean = false,
    val spare: Int? = null, val boxM2: String = "", val boxPcs: Int = 0, val price: String = "",
    val created: Long = 0
) {
    val tileArea get() = a.toDouble() * b
    /** The border strip's tile: its own size, or the main tile's. */
    val sa get() = if (a2 > 0) a2 else a
    val sb get() = if (b2 > 0) b2 else b
    val usesSecond get() = pattern == "chess" || pattern == "border" || accent
}

/**
 * A surface the layout covers: "floor", a wall's letter, or "bath:<id>" (a bath's front panel). A wall is tiled in
 * full height ([mode] full), up to [h1] ("to") or as a band from [h0] to [h1] ("band", a backsplash); [alt] puts the
 * second tile on it (the accent wall).
 */
@Serializable
data class TSurf(val id: String, val mode: String = "full", val h0: Int = 0, val h1: Int = 0, val alt: Boolean = false)

/** Whether surface [s]'s heights can be laid: "up to" a height above 0, a band whose top is above its bottom (a height typed wrong reads 0). */
fun surfHeightsOk(s: TSurf) = when (s.mode) { "to" -> s.h1 > 0; "band" -> s.h0 > 0 && s.h1 > s.h0; else -> true }

/** A surface without a room: a floor [a] × [b], or a wall or backsplash [a] long and [b] high. */
@Serializable
data class TPanel(val kind: String = "floor", val a: Int = 3000, val b: Int = 2000)

/**
 * A shower tray or a bath marked in a room: against [wall], [off] from its start corner, [w] along it, [d] into the
 * room, [h] high. Tiles stop round it; a bath's front can be tiled.
 */
@Serializable
data class TFix(val id: String, val type: String = "tray", val wall: String = "A", val off: Int = 0, val w: Int = 900, val d: Int = 900, val h: Int = 150)

/** A room's tiling extras: its tray and bath, and the waterproofing (floor and [wpUp] up the walls, the shower zone to [showerH]). */
@Serializable
data class TileRoom(val roomId: String, val fixes: List<TFix> = emptyList(), val wp: Boolean = false, val wpUp: Int = 200, val showerH: Int = 1800)

/** A tile's look: a plain colour ("c"), or a drawn marble ("m"), wood ("w") or concrete ("k") of base colour [rgb]. */
class Look(val id: String, val kind: String, val rgb: Int, val vein: Int = 0)

val LOOKS = listOf(
    Look("white", "c", 0xF3F3F0), Look("cream", "c", 0xEADFCB), Look("lgrey", "c", 0xCFCECA), Look("grey", "c", 0x8D9096),
    Look("graph", "c", 0x3A3D43), Look("black", "c", 0x1F2023), Look("sage", "c", 0x93A792), Look("blue", "c", 0x5D7FA8),
    Look("terra", "c", 0xB8673F),
    Look("carrara", "m", 0xF1F0EC, 0x9EA2A8), Look("calacatta", "m", 0xF3EEE4, 0xB89A63), Look("nero", "m", 0x2C2C2F, 0xD8D8D8),
    Look("oak", "w", 0xC09869), Look("walnut", "w", 0x7B5337), Look("ash", "w", 0xDCCAA8),
    Look("cement", "k", 0xAAA9A5), Look("dcement", "k", 0x6E6F71)
)

fun lookOf(id: String) = LOOKS.firstOrNull { it.id == id } ?: LOOKS[0]

/** The sizes offered first, short side first (mm). */
val TILE_SIZES = listOf(200 to 200, 300 to 300, 300 to 600, 600 to 600, 600 to 1200, 200 to 600)

/** The patterns, and the places of the gallery (Pol, Devor, Hammom, Oshxona fartuk). */
val PATTERNS = listOf("straight", "brick2", "brick3", "diagonal", "herring", "chess", "border")
val PLACES = listOf("floor", "wall", "bath", "apron")

/** A gallery card: the layout it starts from; [surf] what it covers in a room ("floor", "walls" or "apron"). */
class TModel(val id: String, val place: String, val pattern: String, val a: Int, val b: Int, val look: String, val look2: String = "graph",
             val surf: String = if (place == "floor") "floor" else if (place == "apron") "apron" else "walls", val a2: Int = 0, val b2: Int = 0, val accent: Boolean = false)

val T_MODELS = listOf(
    TModel("fl.straight", "floor", "straight", 600, 600, "cement"),
    TModel("fl.brick2", "floor", "brick2", 300, 600, "lgrey"),
    TModel("fl.brick3", "floor", "brick3", 200, 600, "oak"),
    TModel("fl.diagonal", "floor", "diagonal", 300, 300, "cream"),
    TModel("fl.herring", "floor", "herring", 200, 600, "walnut"),
    TModel("fl.chess", "floor", "chess", 300, 300, "white", "black"),
    TModel("fl.border", "floor", "border", 600, 600, "calacatta", "nero", a2 = 200, b2 = 600),
    TModel("wl.straight", "wall", "straight", 300, 600, "white"),
    TModel("wl.brick2", "wall", "brick2", 200, 600, "cream"),
    TModel("wl.big", "wall", "straight", 600, 1200, "carrara"),
    TModel("wl.border", "wall", "border", 300, 600, "lgrey", "graph", a2 = 200, b2 = 600),
    TModel("wl.herring", "wall", "herring", 200, 600, "sage"),
    TModel("bt.straight", "bath", "straight", 300, 600, "white"),
    TModel("bt.accent", "bath", "straight", 300, 600, "white", "blue", accent = true),
    TModel("bt.marble", "bath", "straight", 600, 1200, "carrara"),
    TModel("bt.floor", "bath", "chess", 300, 300, "white", "graph", surf = "floor"),
    TModel("bt.diag", "bath", "diagonal", 300, 300, "lgrey", surf = "floor"),
    TModel("ap.brick2", "apron", "brick2", 200, 600, "white"),
    TModel("ap.herring", "apron", "herring", 200, 600, "terra"),
    TModel("ap.marble", "apron", "straight", 600, 1200, "calacatta"),
    TModel("ap.chess", "apron", "chess", 200, 200, "white", "blue")
)

fun tModel(id: String) = T_MODELS.firstOrNull { it.id == id }

/** A new layout from a gallery card. */
fun layoutOf(m: TModel, id: String, now: Long = 0) = TileLayout(id, m.id, m.place, m.pattern, m.a, m.b, joint = if (m.b >= 1200) 2 else if (m.place == "floor") 3 else 2,
    start = "center", look = m.look, look2 = m.look2, a2 = m.a2, b2 = m.b2, accent = m.accent, created = now)

/** The backsplash band the app starts with: from the worktop (900) 600 up. */
const val APRON_H0 = 900
const val APRON_H1 = 1500

/** The usual spare: 10 % for diagonal and herringbone (and anything laid at 45°), else 5 %. */
fun spareOf(l: TileLayout) = l.spare ?: if (l.pattern == "diagonal" || l.pattern == "herring" || l.rot == 45) 10 else 5

/** Tiles in a usual box of tiles [a] × [b]. */
fun piecesPerBox(a: Int, b: Int): Int {
    val m2 = a.toDouble() * b / 1e6
    return when {
        m2 >= .7 -> 2                       // 600 × 1200
        m2 >= .35 -> 4                      // 600 × 600
        m2 >= .17 -> 8                      // 300 × 600
        else -> maxOf(1, (1.2 / m2 + 1e-6).toInt())   // smaller tiles: about 1,2 m² a box (300 × 300: 13, 200 × 600: 10)
    }
}

/** Tiles in a box of layout [l]: as set, or the usual. */
fun perBox(l: TileLayout, a: Int = l.a, b: Int = l.b): Int {
    if (l.boxPcs > 0 && a == l.a && b == l.b) return l.boxPcs
    val m2 = l.boxM2.replace(',', '.').toDoubleOrNull()
    if (m2 != null && m2 > 0 && a == l.a && b == l.b) return maxOf(1, (m2 * 1e6 / (a.toDouble() * b) + 1e-6).toInt())
    return piecesPerBox(a, b)
}
