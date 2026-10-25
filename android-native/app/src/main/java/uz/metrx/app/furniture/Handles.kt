package uz.metrx.app.furniture

/*
 * Handles per door and per drawer, soft close per section (founder's decisions, 25 Oct 2026). [Module.handles] is the
 * piece's master switch ("Tutqichsiz" in Change for all turns it off); with it on, the fronts left without a handle are
 * kept where they stay put when the box changes: a kitchen unit's or a bed's in [Module.noHandle], a section's doors
 * in [Section.noHandle], a section's drawers on the drawer itself ([Insert.push]): an open section's, and the ones behind
 * its doors (hinged or sliding). A front without a handle opens by a push latch, counted in the hardware; a glass door in
 * its aluminium frame never has a handle. A piece that opens by its edge ([opensByEdge]: the mirror cabinet over a
 * basin) needs no latch for a front without one. An older order (none of these set) looks as it did: its box-wide
 * switch is every front's value. Pure Kotlin, unit-tested (HandlesTest).
 *
 * Front keys, as the 3D names them within the box: "f0".. the box's own doors or drawers (a kitchen unit, top down for
 * drawers; a dishwasher's front), "bd0".. a bed's drawers, "s0:f0".. a section's doors, "s0:d120" a section's drawer at
 * 120 mm (an open section's, or one behind the doors).
 */

/**
 * A front that takes a handle or a push latch: its [key]; its section (-1: the box's own); a drawer; a glass door;
 * [inner] a drawer behind the doors (hinged or sliding), hidden on the doors' picture (picked from a row of its own).
 */
data class HFront(val key: String, val sec: Int, val drawer: Boolean, val glass: Boolean = false, val inner: Boolean = false)

/** The pieces that open by their edge, without a handle and without a push latch (Cabinets.kt builds them without handles). */
val EDGE_TYPES = setOf("mirrorC")

/** Whether [f] opens by its edge: a front of it without a handle needs no push latch and shows no push mark. */
fun opensByEdge(f: Furniture) = f.type in EDGE_TYPES

/** The fronts of [m] that take a handle or a push latch, as the pictures draw them (left to right, drawers top down). */
fun handleFronts(m: Module): List<HFront> = when {
    m.type == "filler" -> emptyList()
    m.type == "gap" -> if (m.app == "dishwasher" && m.fronts.kind != "open") listOf(HFront("f0", -1, false)) else emptyList()
    m.type == "bed" -> bedDrawers(m, Workshop()).indices.map { HFront("bd$it", -1, true) }
    m.type in ITEM_MODS -> emptyList()
    m.type == "wardrobe" -> m.sections.flatMapIndexed { i, s ->
        // the section's drawers top down: an open section's faces, or behind its doors (hinged, or the sliding ones)
        fun drawers(inner: Boolean) = s.inserts.filter { it.kind == "drawer" }.sortedByDescending { it.pos }.map { HFront("s$i:d${it.pos}", i, true, inner = inner) }
        when {
            s.knee -> emptyList()
            s.fronts.kind == "open" -> drawers(m.slide != null)
            m.slide != null -> drawers(true)
            s.fronts.kind == "door" -> List(s.fronts.n.coerceAtLeast(0)) { j -> HFront("s$i:f$j", i, false, s.face == "glass") } + drawers(true)
            s.fronts.kind == "drawer" -> List(s.fronts.n.coerceAtLeast(0)) { j -> HFront("s$i:f$j", i, true) }
            else -> emptyList()
        }
    }
    m.fronts.kind == "door" || m.fronts.kind == "drawer" -> List(m.fronts.n.coerceAtLeast(0)) { HFront("f$it", -1, m.fronts.kind == "drawer") }
    else -> emptyList()
}

private fun secOf(key: String): Pair<Int, String>? {
    if (!key.startsWith("s")) return null
    val c = key.indexOf(':'); if (c < 0) return null
    val i = key.substring(1, c).toIntOrNull() ?: return null
    return i to key.substring(c + 1)
}

/** Whether front [key] of [m] has a handle (else a push latch opens it). */
fun hasHandle(m: Module, key: String): Boolean {
    if (!m.handles) return false
    val (i, k) = secOf(key) ?: return key !in m.noHandle
    val s = m.sections.getOrNull(i) ?: return false
    return when {
        k.startsWith("d") -> { val pos = k.drop(1).toIntOrNull(); s.inserts.firstOrNull { it.kind == "drawer" && it.pos == pos }?.push != true }
        else -> { val j = k.drop(1).toIntOrNull() ?: return false; !(s.fronts.kind == "door" && s.face == "glass") && j !in s.noHandle }
    }
}

/** Whether door [j] of section [i] has a handle. */
fun doorHandle(m: Module, i: Int, j: Int) = hasHandle(m, "s$i:f$j")

/** Whether drawer [x] of a section (an open one's, or behind the doors) has a handle. */
fun drawerHandle(m: Module, x: Insert) = m.handles && !x.push

/** [m] with no exception left: every front with a handle ([on]) or none (the master off). */
fun allHandles(m: Module, on: Boolean): Module = m.copy(handles = on, noHandle = emptyList(),
    sections = m.sections.map { s -> if (s.noHandle.isEmpty() && s.inserts.none { it.push }) s else s.copy(noHandle = emptyList(), inserts = s.inserts.map { if (it.push) it.copy(push = false) else it }) })

/** The master on with every front listed as without a handle: as [m] with the master off looks. */
private fun masterOn(m: Module): Module {
    if (m.handles) return m
    val fr = handleFronts(m)
    // the drawers that take a handle (an open section's, the ones behind the doors), each pushed
    val drawers = fr.filter { it.key.contains(":d") }.map { it.key }.toSet()
    return m.copy(handles = true, noHandle = fr.filter { it.sec < 0 }.map { it.key },
        sections = m.sections.mapIndexed { i, s ->
            val x = if (drawers.none { it.startsWith("s$i:") }) s else s.copy(inserts = s.inserts.map { if (it.kind == "drawer" && "s$i:d${it.pos}" in drawers) it.copy(push = true) else it })
            when (s.fronts.kind) {
                "door", "drawer" -> x.copy(noHandle = (0 until s.fronts.n.coerceAtLeast(0)).toList())
                else -> x
            }
        })
}

/** [m] with front [key] given a handle ([on]) or a push latch; the other fronts stay as they look. */
fun withHandle(m: Module, key: String, on: Boolean): Module {
    if (hasHandle(m, key) == on) return m
    val x = masterOn(m)
    val (i, k) = secOf(key) ?: return x.copy(noHandle = if (on) x.noHandle - key else (x.noHandle + key).distinct())
    return x.copy(sections = x.sections.mapIndexed { n, s ->
        if (n != i) s
        else if (k.startsWith("d")) { val pos = k.drop(1).toIntOrNull(); var done = false
            s.copy(inserts = s.inserts.map { if (!done && it.kind == "drawer" && it.pos == pos) { done = true; it.copy(push = !on) } else it }) }
        else { val j = k.drop(1).toIntOrNull() ?: return@mapIndexed s; s.copy(noHandle = if (on) s.noHandle - j else (s.noHandle + j).distinct().sorted()) }
    })
}

/** [m] with front [key]'s handle the other way. */
fun toggleHandle(m: Module, key: String): Module = withHandle(m, key, !hasHandle(m, key))

/** How many of [m]'s fronts have a handle, and how many open by a push latch. */
fun handleSplit(m: Module): Pair<Int, Int> = handleFronts(m).partition { hasHandle(m, it.key) }.let { it.first.size to it.second.size }

/** A section's doors with their stale choices dropped: after a change of its fronts the door numbers mean other doors. */
fun frontsChanged(old: Section, new: Section): Section =
    if (old.fronts == new.fronts || new.noHandle.isEmpty()) new else new.copy(noHandle = if (old.fronts.kind == new.fronts.kind) new.noHandle.filter { it < new.fronts.n } else emptyList())

/** A kitchen unit (or another box's own fronts) with its stale choices dropped after its fronts changed. */
fun frontsChanged(old: Module, new: Module): Module =
    if (old.fronts == new.fronts || new.noHandle.isEmpty()) new
    else new.copy(noHandle = if (old.fronts.kind == new.fronts.kind) new.noHandle.filter { k -> (k.removePrefix("f").toIntOrNull() ?: 0) < new.fronts.n || !k.startsWith("f") } else new.noHandle.filter { !it.startsWith("f") })

/* ---------------- soft close ---------------- */

/** Whether section [i]'s doors close softly: its own choice, else the box's. */
fun softOf(m: Module, i: Int): Boolean = m.sections.getOrNull(i)?.soft ?: m.soft

/** [m] with section [i]'s soft close set to [on] (back to following the box when that is the box's). */
fun withSoft(m: Module, i: Int, on: Boolean): Module = m.copy(sections = m.sections.mapIndexed { k, s -> if (k == i) s.copy(soft = on.takeIf { it != m.soft }) else s })

/** [m] with every section closing as [on]: the box's value, no section of its own. */
fun softAll(m: Module, on: Boolean): Module = m.copy(soft = on, sections = m.sections.map { if (it.soft == null) it else it.copy(soft = null) })

/* ---------------- a piece built again ---------------- */

/** A front's place that survives a rebuild: an open section's drawers by their order from the top, the rest by key. */
private fun ordKeys(m: Module): List<Pair<String, String>> {
    val fr = handleFronts(m)
    return fr.map { f -> if (f.drawer && f.key.contains(":d")) "s${f.sec}:d#" + fr.filter { it.sec == f.sec && it.key.contains(":d") }.indexOf(f) to f.key else f.key to f.key }
}

/**
 * A piece of several boxes built again ([n]) from [f]: no handles at all stays so; otherwise each box (in order) keeps
 * its fronts without a handle where they still are, and its soft close.
 */
fun keepFrontChoices(f: Furniture, n: Furniture): Furniture {
    val olds = f.modules.filter { takesHandles(it) }
    val bare = isBare(f)
    var k = 0
    return n.copy(modules = n.modules.map { m2 ->
        if (!takesHandles(m2)) return@map m2
        if (bare) return@map allHandles(m2, false)
        val m1 = olds.getOrNull(k++) ?: return@map m2
        var out = softAll(m2, m1.soft).let { x -> x.copy(sections = x.sections.mapIndexed { i, s -> s.copy(soft = m1.sections.getOrNull(i)?.soft) }) }
        val newKeys = ordKeys(out).toMap()
        val off = ordKeys(m1).filter { (_, key) -> !hasHandle(m1, key) }.mapNotNull { (o, _) -> newKeys[o] }
        if (!m1.handles && off.size == handleFronts(m1).size) out = allHandles(out, false)
        else off.forEach { key -> out = withHandle(out, key, false) }
        out
    })
}

/** A piece that has fronts but not one handle (the whole of it "Tutqichsiz"). */
fun isBare(f: Furniture): Boolean = f.modules.any { takesHandles(it) && handleFronts(it).isNotEmpty() } && !hasHandles(f)
