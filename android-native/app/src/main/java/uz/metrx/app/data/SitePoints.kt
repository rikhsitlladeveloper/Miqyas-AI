package uz.metrx.app.data

/*
 * Site points of a furniture order's room (furniture plan section 5): what the furniture must keep clear of.
 * Pure Kotlin, unit-tested (SitePointsTest).
 */

/** The kinds, in the sheet's order. */
val PT_TYPES = listOf("socket", "switch", "cold", "hot", "sewer", "gas", "meter")

/** A new point's height from the floor, its diameter (sewer) or width (meter) and the meter's height, mm. */
fun pointDefaults(t: String): Triple<Int, Int, Int> = when (t) {
    "socket" -> Triple(300, 0, 0)
    "switch" -> Triple(900, 0, 0)
    "cold", "hot" -> Triple(550, 0, 0)
    "sewer" -> Triple(450, 50, 0)
    "gas" -> Triple(1000, 0, 0)
    "meter" -> Triple(1500, 300, 400)
    else -> Triple(500, 0, 0)
}

/** Width and height a point takes on the wall, mm: a socket plate, a pipe, the meter's box. */
fun pointSize(x: SitePoint): Pair<Int, Int> = when (x.t) {
    "socket", "switch" -> 86 to 86
    "cold", "hot", "gas" -> 32 to 32
    "sewer" -> x.d.coerceAtLeast(40).let { it to it }
    "meter" -> x.d.coerceAtLeast(100) to x.mh.coerceAtLeast(100)
    else -> 40 to 40
}

/** "pt.offBig" past the wall's length [L], "pt.hBig" above the room's height [H]; null when fine or not measured yet. */
fun pointProblem(x: SitePoint, L: Int?, H: Int?): String? = when {
    L != null && x.off > L -> "pt.offBig"
    H != null && x.h > H -> "pt.hBig"
    else -> null
}
