package uz.metrx.app.core

import kotlinx.serialization.Serializable
import kotlin.math.ceil
import kotlin.math.max

/*
 * The Measure page's small calculator (prototype measure.js): area, net wall, volume, a sum of lengths, and the brick
 * tool (founder's choice B): one brick layer over the wall face less an optional opening, with spare and mortar.
 * Geometry only: nothing here is written to an estimate.
 */

/** Brick length, width, height and joint in mm, spare in % (prototype QB_DEF). */
@Serializable
data class BrickSpec(val l: Int = 250, val w: Int = 120, val h: Int = 65, val j: Int = 10, val s: Int = 5)

/** The two usual Uzbek bricks (prototype QB_PRESETS). */
val BRICK_PRESETS = listOf(Triple(250, 120, 65), Triple(250, 120, 88))
/** What each brick value may be (prototype QB_LIM). */
val BRICK_LIMITS = mapOf("l" to 100..600, "w" to 50..400, "h" to 30..300, "j" to 0..30, "s" to 0..30)

/** Bricks (whole, spare included) and mortar in m³ for a wall face of [faceMm2] (prototype qbCount, one layer). */
fun brickCount(faceMm2: Double, b: BrickSpec): Pair<Long, Double> {
    val n = faceMm2 / ((b.l + b.j).toDouble() * (b.h + b.j))
    val bricks = ceil(n * (100 + b.s) / 100 - 1e-9).toLong()
    val thick = b.w.toDouble()                     // one layer: half a brick thick
    val mortar = max(0.0, faceMm2 * thick - n * b.l * b.w * b.h) / 1e9
    return bricks to mortar
}

/** The slots each tool fills, in order (prototype QC_SLOTS); "sum" takes any number. */
val CALC_SLOTS = mapOf("area" to listOf("L", "W"), "wall" to listOf("L", "H", "ow", "oh"), "vol" to listOf("L", "W", "H"), "sum" to emptyList(), "brick" to listOf("L", "H", "ow", "oh"),
    "sheet" to listOf("L", "W"))

/**
 * Furniture makers' tool instead of bricks: whole sheets for a surface of [areaMm2] with [waste] % added. The sheet is
 * 2800 × 2070 mm until the workshop settings arrive (furniture plan section 6.2).
 */
fun sheetsFor(areaMm2: Double, sheetL: Int = 2800, sheetW: Int = 2070, waste: Int = 15): Int =
    ceil(areaMm2 * (100 + waste) / 100 / (sheetL.toDouble() * sheetW) - 1e-9).toInt()
