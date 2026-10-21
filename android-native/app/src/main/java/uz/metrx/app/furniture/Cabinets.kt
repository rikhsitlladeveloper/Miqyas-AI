package uz.metrx.app.furniture

import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.min

/*
 * More furniture types (furniture plan Stage 2): living room (TV unit, shelving, sideboard), bedroom and other (dresser,
 * nightstand, vanity, hallway, desk). Each is a cabinet on the wardrobe's engine: one carcass split into sections with
 * doors, drawers, shelves and rails, so the designer, the parts, the hardware, the price, the 3D and the documents are
 * the same. Pure Kotlin, unit-tested (CabinetsTest). The sizes are defaults for the founder's makers to check.
 */

/** The types, by group: living room, then bedroom and other. */
val LIVING_TYPES = listOf("tv", "shelving", "sideboard")
val BEDROOM_TYPES = listOf("dresser", "nightstand", "vanity", "hallway", "desk")
val CASE_TYPES = LIVING_TYPES + BEDROOM_TYPES

/** A type's usual size, width × height × depth, mm, and whether it stands on legs (else on a plinth). */
data class TypeSize(val w: Int, val h: Int, val d: Int, val legs: Boolean)

fun typeSize(type: String) = when (type) {
    "tv" -> TypeSize(1800, 500, 450, true)
    "shelving" -> TypeSize(1200, 2000, 350, false)
    "sideboard" -> TypeSize(1600, 850, 450, true)
    "dresser" -> TypeSize(1000, 850, 450, true)
    "nightstand" -> TypeSize(450, 500, 400, true)
    "vanity" -> TypeSize(800, 800, 450, true)
    "hallway" -> TypeSize(1200, 2000, 400, false)
    "desk" -> TypeSize(1200, 750, 600, true)
    else -> TypeSize(1000, 2200, W_DEPTH, false)
}

/**
 * [n] drawers filling a section [ih] high inside. Their faces are seen, set in the carcass: [g] apart and [g] from the
 * bottom and the top, as the doors' gap.
 */
private fun drawers(n0: Int, ih: Int, g: Int): List<Insert> {
    // a low cabinet takes fewer drawers: each keeps about 100 mm, all inside
    val n = min(n0, max(1, (ih + 20) / 100))
    val h = ((ih - g * (n + 1)) / n).coerceAtLeast(80)
    return List(n) { i -> Insert("drawer", pos = g + i * (h + g), h = h) }
}

/**
 * A new cabinet of [type], [w] × [h] × [d] on [wall] at [x]; [h] is the whole height, legs included. Its sections
 * follow the type: drawers in open sections have faces in the front material; a desk's knee space has no bottom or back.
 */
fun cabinetTemplate(type: String, ws: Workshop, wall: String, x: Int, w: Int, h: Int, d: Int): Module {
    val sz = typeSize(type)
    val base = Module(uid(), "wardrobe", w, if (sz.legs) h - ws.legH else h, d, x = x, wall = wall, legs = sz.legs, label = "")
    val ih = wardInnerH(base, ws.t)
    val g = ws.gap10 / 10
    val open = Fronts("open", 0)
    fun door(sw: Int) = Fronts("door", if (sw >= 600) 2 else 1)
    fun shelves(n: Int) = List(n) { Insert("shelf") }
    val secs: List<Section> = when (type) {
        "tv" -> listOf(Section(w / 3, open, drawers(2, ih, g)), Section(w / 3, open, listOf(Insert("shelf", pos = ih / 2))), Section(w - 2 * (w / 3), Fronts("door", 1)))
        "shelving" -> List(maxOf(1, (w + 300) / 600)) { Section(0, open, shelves(4)) }
        "sideboard" -> listOf(Section(w / 2, door(w / 2), listOf(Insert("shelf", pos = ih / 2))), Section(w - w / 2, open, drawers(3, ih, g)))
        "dresser" -> listOf(Section(w, open, drawers(4, ih, g)))
        "nightstand" -> listOf(Section(w, open, drawers(2, ih, g)))
        "vanity" -> listOf(Section(w, door(w)))
        "hallway" -> listOf(Section(w / 2, Fronts("door", 1), listOf(Insert("shoe", pos = 0)) + shelves(3)),
            // the open side: a bench to sit on over the shoe rack (its top about 480 from the floor), coats on a rail above
            Section(w - w / 2, open, listOf(Insert("shoe", pos = 0), Insert("shelf", pos = 480 - PLINTH - 2 * ws.t), Insert("rail", pos = ih - 120))))
        "desk" -> listOf(Section(minOf(450, w / 3), open, drawers(3, ih, g)), Section(w - minOf(450, w / 3), open, emptyList(), knee = true))
        else -> listOf(Section(w, door(w)))
    }
    val split = splitSections(w, secs.map { if (it.w > 0) it.copy(lock = true) else it }).map { it.copy(lock = false) }
    return base.copy(sections = split.map { s -> if (s.inserts.count { it.kind == "shelf" && it.pos == 0 } > 1) spreadShelves(s, ih, ws.t) else s })
}

/** A section is a knee space when the cabinet's type leaves it empty underneath (a desk). */
fun hasKnee(m: Module) = m.sections.any { it.knee }
