package uz.metrx.app.report

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
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
fun snapshotOf(p: Project, s: Settings, pdf: PdfParts = s.pdf): Snap = snapshotOf(p, s.unit, s.builderName, s.builderPhone, pdf)

fun snapshotOf(p: Project, unit: LenUnit, builderName: String, builderPhone: String, pdf: PdfParts): Snap {
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
        name = p.name, customer = p.customer, phone = p.phone, address = p.address, location = p.location,
        currency = p.currency, precision = p.precision, unit = if (unit == LenUnit.CM) "cm" else "m", lang = l.code, notes = p.reportNotes,
        builderName = builderName, builderPhone = builderPhone, pdf = pdf, rooms = rooms, estimate = p.estimate, extras = extras
    )
}

private val json = Json { encodeDefaults = true }

/**
 * What decides whether the draft still matches an issued quote (prototype fingerprint): the parties, currency, language,
 * unit, notes, every room's name, measurements, openings, shape and chosen views, the estimate and the extras.
 */
fun fingerprint(sn: Snap): String {
    fun str(v: String?) = if (v == null) JsonNull else JsonPrimitive(v)
    val rooms = JsonArray(sn.rooms.map { sr ->
        val r = sr.room
        JsonArray(listOf(
            str(r.name),
            JsonArray(r.dims.keys.sorted().map { k -> JsonArray(listOf(str(k), r.dims[k]?.v?.let { JsonPrimitive(it) } ?: JsonNull)) }),
            json.encodeToJsonElement(r.openings),
            r.poly?.let { json.encodeToJsonElement(it) } ?: JsonNull,
            JsonPrimitive(r.rot),
            JsonArray(r.views.map { str(it.id) })
        ))
    })
    val all: List<JsonElement> = listOf(
        str(sn.name), str(sn.customer), str(sn.address), str(sn.currency), JsonPrimitive(sn.precision), str(sn.lang), str(sn.unit), str(sn.notes),
        JsonArray(listOf(str(sn.builderName), str(sn.builderPhone))), rooms, json.encodeToJsonElement(sn.estimate),
        JsonArray(sn.extras.map { x -> JsonArray(listOf(str(x.id), JsonPrimitive(x.edited), str(x.name))) })
    )
    return JsonArray(all).toString()
}
