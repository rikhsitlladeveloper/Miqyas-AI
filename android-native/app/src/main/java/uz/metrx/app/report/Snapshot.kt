package uz.metrx.app.report

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.encodeToJsonElement
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Settings
import uz.metrx.app.data.PdfParts
import uz.metrx.app.data.Project
import uz.metrx.app.data.Snap
import uz.metrx.app.data.SnapExtra
import uz.metrx.app.data.SnapRoom
import uz.metrx.app.data.floorName
import uz.metrx.app.geo.LenUnit

/**
 * The report's content as it stands (prototype snapshotOf + the workspace module's extras): the rooms the builder kept
 * in the report, with the 3D views kept, each with its workspace's name in the report language; the drawings, photos
 * and notes chosen for the report; the builder, the estimate and the PDF parts.
 */
fun snapshotOf(p: Project, s: Settings, pdf: PdfParts = s.pdf): Snap =
    snapshotOf(p, s.unit, s.builderName, s.builderPhone, pdf, s.angleSnap).let { if (p.isFurniture) furnSnap(it, p, s.workshop, s.mats, s.hws) else if (p.isElec) elecSnap(it, p, s.angleSnap) else if (p.isPlumb) plumbSnap(it, p, s.angleSnap)
        else if (p.isWin) winSnap(it, p, if (s.advanced) s.trade.win else null) else if (p.isTiler) tileSnap(it, p) else it }
        .let { if (p.isElec || p.isPlumb || p.isWin) withCalcRooms(it, p) else it }.copy(roomLabel = s.roomLabel)

/** A tiler's order's part of the snapshot: its layouts and rooms' extras, for the layout drawings. */
fun tileSnap(sn: Snap, p: Project): Snap = if (p.tiles.isEmpty()) sn else sn.copy(tiles = p.tiles, troom = p.troom)

/** The rooms left out of the report, so a trade's circuits, pipes and windows are worked out with every room (only the ticked ones are drawn). */
fun withCalcRooms(sn: Snap, p: Project): Snap {
    val l = Lang.of(p.reportLang)
    val out = p.rooms.filter { p.reportRooms[it.id] == false }.map { r -> SnapRoom(r.copy(views = emptyList()), p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, l) } ?: "") }
    return if (out.isEmpty()) sn else sn.copy(calcRooms = out)
}

/** An electrician's order's part of the snapshot: its devices, panel and rooms, each room's kind written down. */
fun elecSnap(sn: Snap, p: Project, snap: Boolean): Snap {
    if (p.elec.empty) return sn
    val kinds = p.rooms.mapNotNull { r -> uz.metrx.app.elec.ctxOf(p, r.id, snap)?.let { r.id to it.kind } }.toMap()
    val rooms = kinds.map { (id, k) -> p.elec.room(id).copy(kind = k) } + p.elec.rooms.filter { it.roomId !in kinds }
    return sn.copy(elec = p.elec.copy(rooms = rooms))
}

/** A plumber's order's part of the snapshot: its fixtures, outlets, riser and rooms, each room's kind written down. */
fun plumbSnap(sn: Snap, p: Project, snap: Boolean): Snap {
    if (p.plumb.empty) return sn
    val kinds = p.rooms.mapNotNull { r -> uz.metrx.app.plumb.ctxOf(p, r.id, snap)?.let { r.id to it.kind } }.toMap()
    val rooms = kinds.map { (id, k) -> p.plumb.room(id).copy(kind = k) } + p.plumb.rooms.filter { it.roomId !in kinds }
    return sn.copy(plumb = p.plumb.copy(rooms = rooms))
}

/** A windows-and-doors order's part of the snapshot: its products, and with [prices] (the advanced app) each one's price. */
fun winSnap(sn: Snap, p: Project, prices: uz.metrx.app.win.WinPrices?): Snap {
    if (p.win.empty) return sn
    val cost = if (prices == null) emptyMap() else uz.metrx.app.win.withReveals(p).associate { (it, r) -> it.id to Math.round(uz.metrx.app.win.itemCost(it, r, prices)) }
    return sn.copy(win = p.win, winPrice = cost)
}

/** The handles the order's pieces have: the usual one, or those picked for a whole piece ("Change for all"). */
private fun handleNames(fs: List<uz.metrx.app.furniture.Furniture>, hws: List<uz.metrx.app.furniture.Hw>, ws: uz.metrx.app.furniture.Workshop): String {
    val usual = uz.metrx.app.furniture.usualHw(hws, "handle")
    val names = fs.filter { uz.metrx.app.furniture.hasHandles(it) }.flatMap { f ->
        when (f.handle) {
            // a kitchen's Gola profile, long verticals by their lengths (Look.kt)
            uz.metrx.app.furniture.GOLA -> listOfNotNull((hws.firstOrNull { it.kind == "gola" } ?: usual)?.name)
            uz.metrx.app.furniture.LONG_V -> uz.metrx.app.furniture.longHandleIds(f, ws).distinct().mapNotNull { id -> hws.firstOrNull { it.id == id }?.name }
            else -> listOfNotNull((hws.firstOrNull { it.id == f.handle && it.kind == "handle" } ?: usual)?.name)
        }
    }.distinct()
    return names.ifEmpty { listOfNotNull(usual?.name) }.joinToString(", ")
}

/**
 * A price line of one of the three price options: "pt." and the option, "pt.eko", "pt.std", "pt.pre" (furniture/
 * PriceTiers.kt TIERS; the iPhone app's keys too). Written only with Project.tri on, outside the fingerprint.
 */
const val TIER_KEY = "pt."

/** The three price options' lines of [sn] (none when the order does not show them). */
fun tierLines(sn: Snap) = sn.flines.filter { it.key.startsWith(TIER_KEY) }

/** A furniture order's part of the snapshot: the furniture, its materials, the price lines and the terms. */
fun furnSnap(sn: Snap, p: Project, ws: uz.metrx.app.furniture.Workshop, mats: List<uz.metrx.app.furniture.Mat>, hws: List<uz.metrx.app.furniture.Hw>): Snap {
    val fs = p.furniture.filter { it.modules.isNotEmpty() }
    val pr = uz.metrx.app.furniture.priceOf(fs, p.fprice, ws, mats, hws)
    // the upper fronts, worktops and backsplashes each piece chose (Look.kt; "wt38" and "splash6" before 25 Oct 2026)
    val used = fs.flatMap { listOfNotNull(it.mats.carcass, it.mats.front, it.mats.back, it.mats.frontUp) }.toSet() +
        fs.filter { it.kind == "kitchen" }.map { uz.metrx.app.furniture.worktopOf(it) } +
        fs.filter { (it.kx?.splash ?: 0) > 0 }.map { f -> f.mats.splash ?: "splash6" }
    // the three price options (Advanced, Project.tri) go with the lines, keyed "pt.eko", "pt.std", "pt.pre"
    val tiers = if (p.tri && fs.isNotEmpty()) uz.metrx.app.furniture.tierPrices(fs, p.fprice, ws, mats, hws).map { uz.metrx.app.data.SnapLine(TIER_KEY + it.tier, it.price.toString()) } else emptyList()
    return sn.copy(furniture = fs, fmats = mats.filter { it.id in used }, flines = pr.lines.map { uz.metrx.app.data.SnapLine(it.key, it.amount.toString()) } + tiers,
        ftotal = pr.price.toString(), fprepay = ws.prepay, fdays = p.fprice.days, finst = p.fprice.inst,
        fhandles = handleNames(fs, hws, ws), fws = ws)
}

fun snapshotOf(p: Project, unit: LenUnit, builderName: String, builderPhone: String, pdf: PdfParts, snap: Boolean = true): Snap {
    val l = Lang.of(p.reportLang)
    val rooms = p.rooms.filter { p.reportRooms[it.id] != false }.map { r ->
        val w = p.floors.firstOrNull { it.id == r.floorId }
        SnapRoom(r.copy(views = r.views.filter { p.reportViews[it.id] != false }), w?.let { floorName(it, l) } ?: "")
    }
    val extras = p.floors.flatMap { w ->
        // an empty drawing has nothing to show (prototype: drawings without marks are left out)
        w.items.filter { it.inReport && !(it.kind == "drawing" && it.els.isEmpty()) }.sortedBy { it.created }
            .map { SnapExtra(it.id, it.kind, it.name, floorName(w, l), it.text, it.checks, it.edited, it.els, it.src, it.W, it.H, it.caption) }
    }
    return Snap(
        name = p.name, customer = p.customer, phone = p.phone, address = p.address,
        // only a builder's report prints the location: furniture and the trades' orders keep it for the maker (room-shapes spec §1)
        location = if (p.industry == "build") p.location else null,
        currency = p.currency, precision = p.precision, unit = if (unit == LenUnit.CM) "cm" else "m", lang = l.code, notes = p.reportNotes,
        builderName = builderName, builderPhone = builderPhone, pdf = pdf, rooms = rooms, estimate = p.estimate, extras = extras, snap = snap, industry = p.industry
    )
}

private val json = Json { encodeDefaults = true }

/** The handle the workshop's list starts with: an order that prints it fingerprints as before handles were printed. */
private const val HANDLE_PRESET = "Tutqich skoba 128"
/** The quote lists the handles (FurniturePages materials table). */
private fun handlesPrinted(sn: Snap) = sn.fhandles.isNotBlank() && sn.furniture.any { uz.metrx.app.furniture.hasHandles(it) }

/**
 * What decides whether the draft still matches an issued quote (prototype fingerprint): the parties, currency, language,
 * unit, notes, every room's name, measurements, openings, columns and niches, site points, shape and chosen views, the
 * estimate and the extras. The parts added later (columns and niches, site points, the customer's phone, the angle
 * snap, a furniture order's prepayment and printed handles, the rooms left out that hold the trade's things, the tile
 * layouts) are tagged and only there when set or not the first default, so a quote issued before them still matches
 * its unchanged draft. A drawn room's own snap is not in its shape: the order's snap is the one its drawn rooms share
 * (the quote's for older rooms), and a room drawn with the other one is tagged.
 */
fun fingerprint(sn: Snap): String = fingerprint(sn, legacy = false)

/**
 * Whether draft [sn] is still issued quote [fp]. A quote of an order without furniture issued before 24 Oct 2026 was
 * fingerprinted without its tagged parts (the phone, the snap, the trades' things: they were left out by mistake), so
 * such a draft also matches that older, shorter fingerprint.
 */
fun sameAsQuote(sn: Snap, fp: String): Boolean = fingerprint(sn) == fp || (sn.furniture.isEmpty() && fingerprint(sn, legacy = true) == fp)

private fun fingerprint(sn: Snap, legacy: Boolean): String {
    fun str(v: String?) = if (v == null) JsonNull else JsonPrimitive(v)
    val drawn = (sn.rooms + sn.calcRooms).mapNotNull { it.room.poly }.map { it.snap ?: sn.snap }.distinct()
    val snap = drawn.singleOrNull() ?: sn.snap
    val rooms = JsonArray(sn.rooms.map { sr ->
        val r = sr.room
        val own = r.poly?.let { it.snap ?: sn.snap }
        JsonArray(listOf(
            str(r.name),
            JsonArray(r.dims.keys.sorted().map { k -> JsonArray(listOf(str(k), r.dims[k]?.v?.let { JsonPrimitive(it) } ?: JsonNull)) }),
            json.encodeToJsonElement(r.openings),
            r.poly?.let { polyJson(it) } ?: JsonNull,
            JsonPrimitive(r.rot),
            JsonArray(r.views.map { str(it.id) })
        ) + (if (r.features.isEmpty()) emptyList() else listOf(JsonArray(listOf(str("ft"), json.encodeToJsonElement(r.features))))) +
            (if (r.points.isEmpty()) emptyList() else listOf(JsonArray(listOf(str("pt"), json.encodeToJsonElement(r.points))))) +
            (if (own == null || own == snap) emptyList() else listOf(JsonArray(listOf(str("sn"), JsonPrimitive(own))))))
    })
    val base: List<JsonElement> = listOf(
        str(sn.name), str(sn.customer), str(sn.address), str(sn.currency), JsonPrimitive(sn.precision), str(sn.lang), str(sn.unit), str(sn.notes),
        JsonArray(listOf(str(sn.builderName), str(sn.builderPhone))), rooms, json.encodeToJsonElement(sn.estimate),
        JsonArray(sn.extras.map { x -> JsonArray(listOf(str(x.id), JsonPrimitive(x.edited), str(x.name))) })
    )
    // the furniture's part in brackets: the tagged parts after it are every order's, not only a furniture order's
    val tagged: List<JsonElement> = (if (sn.furniture.isEmpty()) emptyList() else listOf(json.encodeToJsonElement(sn.furniture), str(sn.ftotal), JsonPrimitive(sn.fdays), JsonPrimitive(sn.finst),
        json.encodeToJsonElement(sn.fmats))) +
        (if (sn.phone.isBlank()) emptyList() else listOf(JsonArray(listOf(str("ph"), str(sn.phone))))) +
        (if (snap) emptyList() else listOf(JsonArray(listOf(str("snap"), JsonPrimitive(false))))) +
        (if (sn.furniture.isEmpty() || sn.fprepay == 50) emptyList() else listOf(JsonArray(listOf(str("pp"), JsonPrimitive(sn.fprepay))))) +
        (if (handlesPrinted(sn) && sn.fhandles != HANDLE_PRESET) listOf(JsonArray(listOf(str("hd"), str(sn.fhandles)))) else emptyList()) +
        (if (sn.elec == null) emptyList() else listOf(JsonArray(listOf(str("el"), json.encodeToJsonElement(sn.elec))))) +
        (if (sn.plumb == null) emptyList() else listOf(JsonArray(listOf(str("pl"), json.encodeToJsonElement(sn.plumb))))) +
        (if (sn.win == null) emptyList() else listOf(JsonArray(listOf(str("dw"), json.encodeToJsonElement(sn.win), json.encodeToJsonElement(sn.winPrice))))) +
        // the rooms left out only count when the trade has something in them (an older quote with an empty one still matches)
        (if (!calcRoomsCount(sn)) emptyList() else listOf(JsonArray(listOf(str("cr"), JsonArray(sn.calcRooms.map { roomJson(it.room) }))))) +
        (if (sn.tiles.isNullOrEmpty()) emptyList() else listOf(JsonArray(listOf(str("tl"), json.encodeToJsonElement(sn.tiles), json.encodeToJsonElement(sn.troom)))))
    return JsonArray(base + if (legacy && sn.furniture.isEmpty()) emptyList() else tagged).toString()
}

/** A drawn room's shape without its own snap (that is tagged on its own, see [fingerprint]). */
private fun polyJson(p: uz.metrx.app.data.Poly): JsonElement = JsonObject((json.encodeToJsonElement(p) as JsonObject) - "snap")

/** A room as JSON, its drawn shape without its own snap. */
private fun roomJson(r: uz.metrx.app.data.Room): JsonElement {
    val o = json.encodeToJsonElement(r) as JsonObject
    return if (r.poly == null) o else JsonObject(o + ("poly" to polyJson(r.poly)))
}

/** Whether the rooms left out of the report hold any of the trade's things: only then do they change its count. */
private fun calcRoomsCount(sn: Snap): Boolean {
    val ids = sn.calcRooms.map { it.room.id }.toSet()
    if (ids.isEmpty()) return false
    val used = (sn.elec?.let { e -> e.devs.map { it.roomId } + listOfNotNull(e.panel?.roomId) } ?: emptyList()) +
        (sn.plumb?.let { e -> e.fixes.map { it.roomId } + e.points.map { it.roomId } + listOfNotNull(e.riser?.roomId) } ?: emptyList()) +
        (sn.win?.items?.mapNotNull { it.roomId } ?: emptyList())
    return used.any { it in ids }
}

/** A room's name in a trade's pages: its workspace's, unless that workspace has more rooms in [all] (then the room's own). */
fun tradeRoomName(sr: SnapRoom, all: List<SnapRoom>, l: Lang): String =
    if (sr.floorLabel.isBlank() || all.count { it.floorLabel == sr.floorLabel } > 1) uz.metrx.app.data.dn(sr.room.name, l) else sr.floorLabel
