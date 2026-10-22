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

/** The types, by group: living room, then bedroom and other, then the gallery's later ones (22 Oct 2026) by room. */
val LIVING_TYPES = listOf("tv", "shelving", "sideboard")
val BEDROOM_TYPES = listOf("dresser", "nightstand", "vanity", "hallway", "desk")
val MORE_TYPES = listOf("pantry", "tvBed", "shelfW", "shelvesW", "shoe", "hallW", "kidsW", "toys", "bookcase", "officeC", "sinkV", "mirrorC", "penal")
val CASE_TYPES = LIVING_TYPES + BEDROOM_TYPES + MORE_TYPES

/** Cabinets that hang on the wall: their bottom [TypeSize.elev] above the floor. */
val HUNG_TYPES = setOf("shelfW", "shelvesW", "mirrorC")

/** Bathroom pieces: moisture-resistant board by default; a vanity and a tall cabinet stand on legs or hang. */
val BATH_TYPES = setOf("sinkV", "mirrorC", "penal", "washer")
val MOUNT_TYPES = setOf("sinkV", "penal")

/**
 * A type's usual size, width × height × depth, mm, and whether it stands on legs (else on a plinth); a hung one's
 * bottom [elev] above the floor (its [h] the carcass alone).
 */
data class TypeSize(val w: Int, val h: Int, val d: Int, val legs: Boolean, val elev: Int = 0)

fun typeSize(type: String) = when (type) {
    "tv" -> TypeSize(1800, 500, 450, true)
    "shelving" -> TypeSize(1200, 2000, 350, false)
    "sideboard" -> TypeSize(1600, 850, 450, true)
    "dresser" -> TypeSize(1000, 850, 450, true)
    "nightstand" -> TypeSize(450, 500, 400, true)
    // a dressing table: drawers beside a knee space, its mirror on the wall above (Pieces.kt)
    "vanity" -> TypeSize(1000, 750, 450, true)
    "hallway" -> TypeSize(1200, 2000, 400, false)
    "desk" -> TypeSize(1200, 750, 600, true)
    "pantry" -> TypeSize(600, 2100, 600, true)
    "tvBed" -> TypeSize(1200, 550, 400, true)
    "shelfW" -> TypeSize(1000, 300, 250, false, 1500)
    "shelvesW" -> TypeSize(1600, 700, 300, false, 1300)
    "shoe" -> TypeSize(800, 1000, 300, true)
    "hallW" -> TypeSize(600, 2100, 400, false)
    "kidsW" -> TypeSize(1000, 1800, 500, false)
    "toys" -> TypeSize(1000, 900, 350, false)
    "bookcase" -> TypeSize(800, 2000, 350, false)
    "officeC" -> TypeSize(900, 2000, 450, false)
    "sinkV" -> TypeSize(800, 850, 450, true)
    "mirrorC" -> TypeSize(600, 700, 150, false, 1250)
    "penal" -> TypeSize(400, 1800, 300, true)
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
    // a hung cabinet has neither legs nor a plinth: its sides end at its bottom
    val base = Module(uid(), "wardrobe", w, if (sz.legs) h - ws.legH else h, d, x = x, wall = wall, legs = sz.legs, label = "",
        elev = sz.elev, base = if (sz.elev > 0) 0 else null)
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
        "vanity" -> listOf(Section(minOf(450, w * 2 / 5), open, drawers(4, ih, g)), Section(w - minOf(450, w * 2 / 5), open, emptyList(), knee = true))
        "hallway" -> listOf(Section(w / 2, Fronts("door", 1), listOf(Insert("shoe", pos = 0)) + shelves(3)),
            // the open side: a bench to sit on over the shoe rack (its top about 480 from the floor), coats on a rail above
            Section(w - w / 2, open, listOf(Insert("shoe", pos = 0), Insert("shelf", pos = 480 - PLINTH - 2 * ws.t), Insert("rail", pos = ih - 120))))
        "desk" -> listOf(Section(minOf(450, w / 3), open, drawers(3, ih, g)), Section(w - minOf(450, w / 3), open, emptyList(), knee = true))
        "pantry", "penal" -> listOf(Section(w, Fronts("door", 1), shelves(5)))
        "tvBed" -> listOf(Section(w / 2, open, listOf(Insert("shelf", pos = ih / 2))), Section(w - w / 2, open, drawers(2, ih, g)))
        "shelfW" -> listOf(Section(w / 2, open), Section(w - w / 2, open))
        // three open boxes, their shelves at a staggered height
        "shelvesW" -> listOf(Section(w / 3, open, listOf(Insert("shelf", pos = ih / 3))), Section(w / 3, open, listOf(Insert("shelf", pos = ih * 2 / 3))),
            Section(w - 2 * (w / 3), open, listOf(Insert("shelf", pos = ih / 3))))
        "shoe", "bookcase" -> listOf(Section(w, door(w), shelves(if (type == "shoe") 3 else 5)))
        "hallW" -> listOf(Section(w, Fronts("door", 1), listOf(Insert("rail", pos = ih - 380), Insert("shelf", pos = ih - 310))))
        // a child reaches the rail at about 1200 from the floor
        "kidsW" -> listOf(Section(w / 2, Fronts("door", 1), listOf(Insert("rail", pos = minOf(ih - 380, 1100)), Insert("shelf", pos = minOf(ih - 380, 1100) + 70))),
            Section(w - w / 2, Fronts("door", 1), shelves(4)))
        "toys" -> listOf(Section(w / 3, open, listOf(Insert("shelf", pos = ih / 2))), Section(w / 3, open, drawers(2, ih, g)), Section(w - 2 * (w / 3), open, listOf(Insert("shelf", pos = ih / 2))))
        "officeC" -> listOf(Section(w / 2, Fronts("door", 1), shelves(4)),
            Section(w - w / 2, Fronts("door", 1), drawers(3, minOf(ih, 600), g) + List(2) { Insert("shelf", pos = 0) }))
        "sinkV" -> listOf(Section(w, door(w)))
        "mirrorC" -> listOf(Section(w, door(w).copy(n = if (w >= 500) 2 else 1), shelves(2), face = "mirror"))
        else -> listOf(Section(w, door(w)))
    }
    val split = splitSections(w, secs.map { if (it.w > 0) it.copy(lock = true) else it }).map { it.copy(lock = false) }
    return base.copy(sections = split.map { s -> if (s.inserts.count { it.kind == "shelf" && it.pos == 0 } > 1) spreadShelves(s, ih, ws.t) else s },
        // a mirror cabinet over a basin has no handles: it opens by its edge
        handles = type != "mirrorC")
}

/** A section is a knee space when the cabinet's type leaves it empty underneath (a desk). */
fun hasKnee(m: Module) = m.sections.any { it.knee }
