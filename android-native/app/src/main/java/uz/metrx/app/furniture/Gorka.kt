package uz.metrx.app.furniture

import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * The guest room's gorka and the big dining table (modern 3D part 6a; founder's decisions of 25 Oct 2026, the approved
 * mockup scratchpad modern3d/modern-3d.html buildGorka; design/furniture/uz-market-research.md: OLX gorkas 270–300 wide
 * × 210 tall with stepped depths, shown with a table for 10–12).
 *
 * The gorka is a piece of several boxes on the wardrobe's engine, so its parts, cut list, hardware, price and 3D come
 * from the same rules as a vitrina's: a lit glass tower at each end (a box with a drawer, a box with a glass door and
 * glass shelves on it), a floating TV base with drawers between them, a bridge of doors over the niche, and the TV
 * panel ([TV_PANEL], a board item) on the wall between. Its modules always go in this order: the first tower's two
 * boxes, the base, the bridge (if any), the panel, the second tower's boxes (if any) — [gorkaRoles] reads them back.
 *
 * The big table is the dining table's module ("table") laid for [Opt.seats] people: a 38 mm stone-look or wood top,
 * two panel legs or metal legs; its chairs are drawn round it ([chairPlaces]) but not priced (the furniture core has no
 * accessories). Pure Kotlin, unit-tested (GorkaTest). The sizes are defaults for the founder's makers to check.
 */

/** The TV panel's module type (Items.kt ITEM_MODS). */
const val TV_PANEL = "tvpanel"

/** The TV sizes the gorka's step offers, inches. */
val GK_TVS = listOf(55, 65, 75, 85)

/** The TV panel's facing: a stone-look slab, wood slats, moulded MDF. */
val GK_PANELS = listOf("stone", "slats", "mould")

/** What each facing is bought as (Hardware.kt AREA_KINDS, by the m²). */
fun panelKind(panel: String) = when (panel) { "slats" -> "tvSlats"; "mould" -> "tvMould"; else -> "tvStone" }

const val GK_TOWER_D = 400
const val GK_BASE_D = 450
const val GK_BRIDGE_D = 300
const val GK_BRIDGE_H = 300
/** A tower's lower box (its drawer) and the plinth under it. */
const val GK_LOW_H = 500
const val GK_PLINTH = 60
/** The floating TV base: its bottom above the floor and its height. */
const val GK_BASE_ELEV = 220
const val GK_BASE_H = 400
/** The panel stands this far in from each tower; it stops this far under the bridge. */
const val GK_PANEL_IN = 80
const val GK_PANEL_GAP = 20
/** The TV niche is at least this wide. */
const val GK_NICHE_MIN = 900
/** The facing over the panel's board (a stone slab, slats, mouldings), mm. */
const val GK_FACING = 22

/** A TV's width and height for its diagonal in inches (16:9), mm. */
fun tvSize(inch: Int): Pair<Int, Int> = (inch * 25.4 * 0.8716).roundToInt() to (inch * 25.4 * 0.4903).roundToInt()

/**
 * A gorka's options: overall width [w] and height [h], a tower's width [tw], the TV [tv] (inches), [towers] 2 or 1,
 * the [bridge] over the niche, the panel's facing [panel], [glass] doors on the towers (else board doors).
 */
data class GkOpts(val w: Int = 3000, val h: Int = 2100, val tw: Int = 500, val tv: Int = 65, val towers: Int = 2, val bridge: Boolean = true,
                  val panel: String = "stone", val glass: Boolean = true)

/** A tower's width held so the niche stays at least [GK_NICHE_MIN] wide. */
fun towerW(o: GkOpts): Int = min(o.tw.coerceIn(300, 800), (o.w - GK_NICHE_MIN) / o.towers.coerceIn(1, 2)).coerceAtLeast(300)

/** One drawer filling an open section [ih] high inside, [g] from its bottom and top (as the doors' gap). */
private fun fill(ih: Int, g: Int) = listOf(Insert("drawer", pos = g, h = ih - 2 * g))

/** A tower's two boxes at [x]: the lower one with its drawer, the upper one with its door and shelves, hinged on [hinge]. */
private fun tower(ws: Workshop, x: Int, tw: Int, h: Int, glass: Boolean, hinge: String): List<Module> {
    val g = ws.gap10 / 10
    val lo0 = Module(uid(), "wardrobe", tw, GK_LOW_H, GK_TOWER_D, x = x, wall = "A", legs = false, base = GK_PLINTH)
    val lo = lo0.copy(sections = listOf(Section(tw, Fronts("open", 0), fill(wardInnerH(lo0, ws.t), g))))
    val up0 = Module(uid(), "wardrobe", tw, max(600, h - GK_LOW_H), GK_TOWER_D, x = x, wall = "A", legs = false, base = 0, elev = GK_LOW_H)
    val ih = wardInnerH(up0, ws.t)
    val s = spreadShelves(Section(tw, Fronts("door", 1), List(max(2, ih / 450)) { Insert("shelf") }, hinge = hinge, face = if (glass) "glass" else ""), ih, ws.t)
    return listOf(lo, up0.copy(sections = listOf(if (glass) s.copy(inserts = s.inserts.map { it.copy(kind = "glass") }) else s)))
}

/** A door is at most this wide (the designer's own check, Wardrobe.kt wc.doorWide). */
const val GK_DOOR_MAX = 600

/**
 * How many doors a new gorka's bridge [nw] wide gets: the fewest that keep each door [GK_DOOR_MAX] or narrower, worked
 * out on the doors' real widths (the sections as [splitSections] shares them, less the edges and gaps). 2000 → 4.
 */
fun bridgeDoors(nw: Int, ws: Workshop): Int = (1..40).firstOrNull { n ->
    splitSections(nw, List(n) { Section(0, Fronts("door", 1)) }).all { s -> frontSizes(s.fronts, frontW(s), GK_BRIDGE_H, ws).all { it.second <= GK_DOOR_MAX } }
} ?: 40

/** The gorka's boxes for [o], from the wall's start ([W_GAP_SIDE]). */
fun gorkaBoxes(ws: Workshop, o: GkOpts): List<Module> {
    val n = o.towers.coerceIn(1, 2)
    val tw = towerW(o)
    val nw = max(GK_NICHE_MIN, o.w - n * tw)
    val h = o.h.coerceAtLeast(1800)
    val x0 = W_GAP_SIDE
    val g = ws.gap10 / 10
    val secs = if (nw >= 1500) 3 else 2
    val base0 = Module(uid(), "wardrobe", nw, GK_BASE_H, GK_BASE_D, x = x0 + tw, wall = "A", legs = false, base = 0, elev = GK_BASE_ELEV)
    val base = base0.copy(sections = splitSections(nw, List(secs) { Section(0, Fronts("open", 0), fill(wardInnerH(base0, ws.t), g)) }))
    val bridge = if (!o.bridge) null else Module(uid(), "wardrobe", nw, GK_BRIDGE_H, GK_BRIDGE_D, x = x0 + tw, wall = "A", legs = false, base = 0,
        elev = h - GK_BRIDGE_H, sections = splitSections(nw, List(bridgeDoors(nw, ws)) { Section(0, Fronts("door", 1)) }))
    val pe = GK_BASE_ELEV + GK_BASE_H
    val panel = itemModule(TV_PANEL, ws, "A", x0 + tw + GK_PANEL_IN, nw - 2 * GK_PANEL_IN, h - GK_BRIDGE_H - GK_PANEL_GAP - pe, 0,
        Opt(panel = o.panel.takeIf { it in GK_PANELS } ?: "stone", tv = o.tv), elev = pe)
    return tower(ws, x0, tw, h, o.glass, "R") + listOfNotNull(base, bridge, panel) + (if (n == 2) tower(ws, x0 + tw + nw, tw, h, o.glass, "L") else emptyList())
}

/** The gorka's options from its step values (the steps' and its designer's keys, Pieces.kt newPiece). */
fun gkOpts(v: (String) -> Int) = GkOpts(v("w"), v("h"), v("tw"), GK_TVS.getOrElse(v("tv")) { 65 }, if (v("one") == 1) 1 else 2, v("nobr") != 1,
    GK_PANELS.getOrElse(v("pn")) { "stone" }, v("solid") != 1)

/** The boxes of a gorka by what they are: its towers' lower and upper boxes (first tower first), the base, the bridge, the panel. */
class GkRoles(val lows: List<Module>, val ups: List<Module>, val base: Module?, val bridge: Module?, val panel: Module?) {
    val towerTop: Int get() = ups.maxOfOrNull { it.elev + it.h } ?: (bridge?.let { it.elev + it.h } ?: 2100)
}

/**
 * The gorka's boxes by their place in its list: 3 cabinets one tower and no bridge, 4 one tower and a bridge, 5 two
 * towers and no bridge, 6 two towers and a bridge. Null for a piece that is not a gorka (or whose boxes are not so).
 */
fun gorkaRoles(f: Furniture): GkRoles? {
    if (f.type != "gorka") return null
    val c = f.modules.filter { it.type == "wardrobe" }
    if (c.size !in 3..6) return null
    val two = c.size >= 5; val br = c.size % 2 == 0
    val lows = listOfNotNull(c[0], if (two) c[c.size - 2] else null)
    val ups = listOfNotNull(c[1], if (two) c[c.size - 1] else null)
    return GkRoles(lows, ups, c[2], if (br) c[3] else null, f.modules.firstOrNull { it.type == TV_PANEL })
}

/** [m] [w] wide: its sections spread again when it changed. */
private fun widen(m: Module, w: Int) = if (m.w == w) m else m.copy(w = w, sections = splitSections(w, m.sections.map { it.copy(lock = false) }))

/**
 * A gorka's boxes where they belong after a change: each tower's upper box as wide as its lower one and on it (the one
 * just [changed] leads), the base and the bridge between the towers (as wide as each other: the bridge leads when it
 * changed), the bridge's top level with the towers', the panel between them over the base.
 */
fun gorkaPack(f: Furniture, changed: String?, ws: Workshop): Furniture {
    val r = gorkaRoles(f) ?: return f
    val base = r.base ?: return f
    val nx = HashMap<String, Module>()
    var x = r.lows[0].x
    fun towerAt(i: Int) {
        val lo = r.lows[i]; val up = r.ups[i]
        val w = if (changed == up.id) up.w else lo.w
        val l2 = widen(lo, w).copy(x = x)
        nx[lo.id] = l2
        nx[up.id] = widen(up, w).copy(x = x, elev = topOf(l2, ws), wall = lo.wall)
        x += w
    }
    towerAt(0)
    val nw = if (r.bridge != null && changed == r.bridge.id) r.bridge.w else base.w
    val bx = x
    nx[base.id] = widen(base, nw).copy(x = bx)
    x += nw
    if (r.lows.size > 1) towerAt(1)
    val top = r.ups.maxOf { nx.getValue(it.id).let { u -> u.elev + u.h } }
    r.bridge?.let { b -> nx[b.id] = widen(b, nw).copy(x = bx, elev = max(base.elev + base.h + 300, top - b.h), wall = base.wall) }
    r.panel?.let { p ->
        val pe = base.elev + base.h
        val pt = (r.bridge?.let { nx.getValue(it.id).elev } ?: (top - GK_BRIDGE_H)) - GK_PANEL_GAP
        nx[p.id] = p.copy(x = bx + GK_PANEL_IN, w = max(200, nw - 2 * GK_PANEL_IN), elev = pe, h = max(200, pt - pe), wall = base.wall)
    }
    return f.copy(modules = f.modules.map { nx[it.id] ?: it })
}

/** A gorka's step values (and its designer's), read back from its boxes. */
fun gorkaVals(f: Furniture, ws: Workshop): Map<String, Int> {
    val r = gorkaRoles(f) ?: return emptyMap()
    val c = f.modules.filter { it.type == "wardrobe" }
    val o = r.panel?.opt ?: Opt()
    return mapOf(
        "w" to (c.maxOf { it.x + it.w } - c.minOf { it.x }),
        "h" to (c.maxOfOrNull { topOf(it, ws) } ?: 2100),
        "tw" to r.lows[0].w,
        "tv" to GK_TVS.indexOf(o.tv).let { if (it < 0) 1 else it },
        "d" to c.maxOf { it.d },
        "one" to if (r.lows.size == 1) 1 else 0,
        "nobr" to if (r.bridge == null) 1 else 0,
        "pn" to GK_PANELS.indexOf(o.panel).coerceAtLeast(0),
        "solid" to if (gorkaGlass(f)) 0 else 1
    )
}

/** Whether the gorka's towers have glass doors. */
fun gorkaGlass(f: Furniture): Boolean = gorkaRoles(f)?.ups?.any { u -> u.sections.any { it.face == "glass" } } == true

/** The gorka with glass doors (and glass shelves) in its towers, or board doors over board shelves; its sizes as they are. */
fun withGorkaGlass(f: Furniture, glass: Boolean): Furniture {
    val r = gorkaRoles(f) ?: return f
    val ids = r.ups.map { it.id }.toSet()
    return f.copy(modules = f.modules.map { m ->
        if (m.id !in ids) m else m.copy(sections = m.sections.map { s ->
            s.copy(face = if (glass) "glass" else "", inserts = s.inserts.map { x -> if (glass && x.kind == "shelf") x.copy(kind = "glass") else if (!glass && x.kind == "glass") x.copy(kind = "shelf") else x })
        })
    })
}

/** The gorka with its TV panel's facing [panel] or TV [tv] (inches) changed. */
fun withGorkaPanel(f: Furniture, panel: String? = null, tv: Int? = null): Furniture = f.copy(modules = f.modules.map { m ->
    if (m.type != TV_PANEL) m else m.copy(opt = (m.opt ?: Opt()).let { o -> o.copy(panel = panel ?: o.panel, tv = tv ?: o.tv) })
})

/** Whether the TV fits its panel: the TV's width at most the panel's less 40 mm. */
fun tvFits(f: Furniture): Boolean {
    val p = gorkaRoles(f)?.panel ?: return true
    return tvSize(p.opt?.tv?.takeIf { it > 0 } ?: 65).first <= p.w - 40
}

/**
 * The gorka's LED strips, mm (the 3D draws the same, Gorka3D.kt): up each side of a tower's glass box, under the
 * floating base and under the bridge.
 */
fun gorkaLedMm(f: Furniture, ws: Workshop): Int {
    val r = gorkaRoles(f) ?: return 0
    return r.ups.sumOf { 2 * wardInnerH(it, ws.t) } + (r.base?.let { it.w - 80 } ?: 0) + (r.bridge?.let { it.w - 60 } ?: 0)
}

/** The gorka's cornice (a neoclassic one): along the top of each tower and of the bridge, mm. */
fun gorkaCorniceMm(f: Furniture): Int {
    val r = gorkaRoles(f) ?: return 0
    return r.ups.sumOf { it.w } + (r.bridge?.w ?: 0)
}

/**
 * The gorka's own hardware (kinds counted like the modules', metre kinds in mm): its LED strips with one driver for
 * every 5 m when the look has LED, the cornice when the look has one. The panel's facing is the panel's (Items.kt).
 */
fun gorkaHardware(f: Furniture, ws: Workshop): Map<String, Int> {
    if (f.type != "gorka") return emptyMap()
    val out = LinkedHashMap<String, Int>()
    if (f.look?.led == true) {
        val mm = gorkaLedMm(f, ws)
        if (mm > 0) { out["led"] = mm; out["ledPsu"] = (mm + 4999) / 5000 }
    }
    if (f.look?.crown == "cornice") gorkaCorniceMm(f).takeIf { it > 0 }?.let { out["cornice"] = it }
    return out
}

/** What a gorka's box is called in its designer (strings key). */
fun gorkaRole(f: Furniture, m: Module): String? {
    val r = gorkaRoles(f) ?: return null
    return when (m.id) {
        in r.lows.map { it.id } -> "gk.box.low"
        in r.ups.map { it.id } -> "gk.box.tower"
        r.base?.id -> "gk.box.base"
        r.bridge?.id -> "gk.box.bridge"
        else -> null
    }
}

/* ---------------- the TV panel ---------------- */

/** The TV panel's boards: its board (the moulded one's is the visible MDF panel, in the fronts' board), the facing over it in the 3D. */
fun panelBoards(m: Module, ws: Workshop): List<Board> {
    val o = m.opt ?: Opt()
    val E = m.elev
    return if (o.panel == "mould") listOf(Board("gk.panel", "front", 0, m.w, E, E + m.h, 0, ws.t))
        else listOf(Board("gk.panelBack", "carcass", 0, m.w, E, E + m.h, 0, ws.t))
}

/** The TV panel's hardware: its facing by the m² (a moulded panel's milling). */
fun panelHardware(m: Module, add: (String, Int) -> Unit) {
    add(panelKind(m.opt?.panel ?: "stone"), m.w * m.h)
}

/* ---------------- the big dining table ---------------- */

/** The big table's seats (its step's choices) and legs (two panel legs, four metal legs). */
val DT_SEATS = listOf(10, 12)
val DT_LEGS = listOf("board", "metal4")

/** A chair stands this far out from the table's edge (its middle); chairs side by side are at least [DT_PITCH] apart. */
const val DT_CHAIR_OUT = 240
const val DT_CHAIR_W = 440
const val DT_PITCH = 500
const val DT_PITCH_MAX = 620

/** A chair round the big table: its middle [a] along the table and [n] out from its back edge; [face] which way it looks (+n, -n, +a, -a). */
data class Chair(val a: Int, val n: Int, val face: String)

/** How many chairs a side [w] long takes at most, each [DT_PITCH] apart. */
fun chairsPerSide(w: Int) = max(1, (w - 100) / DT_PITCH)

/**
 * The chairs round the big table [m]: one at each end, the rest shared by the two long sides, evenly from the middle,
 * [DT_PITCH]–[DT_PITCH_MAX] apart; a table too short for its seats takes fewer chairs along its sides.
 */
fun chairPlaces(m: Module): List<Chair> {
    val seats = m.opt?.seats ?: 0
    if (m.type != "table" || seats <= 0) return emptyList()
    val n = min(max(1, (seats - 2) / 2), chairsPerSide(m.w))
    val sp = min(DT_PITCH_MAX, (m.w - 100) / n)
    val out = ArrayList<Chair>()
    for (i in 0 until n) {
        val a = (m.w / 2.0 + (i - (n - 1) / 2.0) * sp).roundToInt()
        out += Chair(a, -DT_CHAIR_OUT, "+n"); out += Chair(a, m.d + DT_CHAIR_OUT, "-n")
    }
    out += Chair(-DT_CHAIR_OUT, m.d / 2, "+a"); out += Chair(m.w + DT_CHAIR_OUT, m.d / 2, "-a")
    return out
}

/** How many sit at the big table as drawn. */
fun seatsOf(m: Module) = chairPlaces(m).size

/** The big table's two panel legs (each two boards glued) set in from its ends, and the rail between them. */
fun bigTableLegs(m: Module, ws: Workshop, y1: Int): List<Board> {
    val t = ws.t; val W = m.w; val D = m.d
    val ia = min(420, W / 7)
    val out = ArrayList<Board>()
    listOf(ia, W - ia - 2 * t).forEach { a ->
        out += Board("fp.tLeg", "front", a, a + t, 0, y1, 200, D - 200)
        out += Board("fp.tLeg", "front", a + t, a + 2 * t, 0, y1, 200, D - 200)
    }
    out += Board("fp.apron", "front", ia + 2 * t, W - ia - 2 * t, y1 - 150, y1, D / 2 - t / 2, D / 2 + t - t / 2)
    return out
}

/** The worktop strips a big table's top is joined from (600 deep each). */
fun topStrips(m: Module) = max(1, (m.d + 599) / 600)

/** The big table's top: [kind] "stone" or "wood", keeping the decor [cur] where it is of that kind. */
fun dtTop(kind: String, cur: String?): String {
    val d = worktopDecor(cur)
    return if (kind == "wood") worktopFor("wood", d.takeIf { it == "craft" || it == "halifax" } ?: "halifax")
        else worktopFor("stone", d.takeIf { it in setOf("marble", "onyx", "dark") } ?: "marble")
}

/** Whether [f] is the big dining table. */
fun isBigTable(f: Furniture) = f.type == "dining12"

/** The big table's sizes in its designer, mm (its steps' ranges). */
fun bigTableRange(key: String): IntRange = when (key) { "d" -> 900..1300; "h" -> 700..800; else -> 1800..3600 }
