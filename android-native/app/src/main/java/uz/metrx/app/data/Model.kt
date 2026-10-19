package uz.metrx.app.data

import kotlinx.serialization.Serializable

/*
 * The project model of the prototype (design/prototype: newProject(), workspace.js), kept as close as possible
 * so screens and numbers can be compared one to one. Lengths are millimetres, times are epoch ms.
 *
 * Names that start with "@" are not typed text but a strings key, so they follow the app language:
 * "@floor1" and "@floor:2" are "1-qavat" / "2-qavat", "@ws.t.bath" is "Hammom" (see Names.kt).
 *
 * Every class keeps defaults for every field so older saved projects still load after fields are added.
 */

@Serializable
data class Location(val lat: Double, val lng: Double, val acc: Int, val ts: Long)

@Serializable
data class Project(
    val id: String,
    val name: String,
    val customer: String = "",
    val phone: String = "",              // 9 local digits, no +998
    val address: String = "",
    val location: Location? = null,
    val currency: String = "UZS",
    val precision: Int = 0,
    val reportLang: String = "uz",
    val stage: String = "measure",       // measure, estimate, quote, work, done
    val floors: List<Workspace> = emptyList(),
    val rooms: List<Room> = emptyList(),
    val estimate: Estimate = Estimate(),
    val quotes: List<Quote> = emptyList(),
    val reportRooms: Map<String, Boolean> = emptyMap(), // room id -> in the report (default yes)
    val reportViews: Map<String, Boolean> = emptyMap(), // 3D view id -> in the report (default yes)
    val reportNotes: String = "",                       // the report's own note (prototype p.report.notes)
    val created: Long = 0,
    val edited: Long = 0,
    /** "build" (a builder's project) or "furniture" (a furniture order); older projects are builders'. */
    val industry: String = "build",
    /** Furniture: the price agreed with the customer in the smallest unit, "" until the order is approved. */
    val agreed: String = "",
    val payments: List<Payment> = emptyList(),
    /** Furniture orders: the kitchens, wardrobes… designed for it (furniture plan section 6.1). */
    val furniture: List<uz.metrx.app.furniture.Furniture> = emptyList(),
    /** Furniture orders: how the customer price is worked out, and the lead time (furniture plan section 6.7). */
    val fprice: uz.metrx.app.furniture.FPrice = uz.metrx.app.furniture.FPrice()
) {
    val isFurniture get() = industry == "furniture"
}

/** Money received for a furniture order: [amount] in the smallest unit; [pre] marks the prepayment. */
@Serializable
data class Payment(val id: String, val amount: String, val ts: Long, val note: String = "", val pre: Boolean = false)

/** A furniture order's stages, in order (furniture plan section 4). */
val F_STAGES = listOf("measure", "design", "quote", "approved", "production", "installed", "paid")

/** A workspace: a place in the project (a floor, a room, a bathroom, the yard…). Stored in Project.floors like the prototype. */
@Serializable
data class Workspace(
    val id: String,
    val name: String,
    val type: String = "floor",          // floor, room, bath, kitchen, balcony, outdoor, other
    val items: List<Item> = emptyList(), // drawings, photos and notes; room plans live in Project.rooms
    val created: Long = 0
)

@Serializable
data class Check(val id: String, val text: String = "", val done: Boolean = false)

/**
 * One mark on a drawing or a photo (prototype it.els): [t] pen, line, dim, arrow or text; [pts] in the item's own
 * coordinates (1000 wide); [c] ink, cobalt or red; [w] pen width 1 thin, 2 thick; [v] a line's or dimension's length in mm
 * (null = not given yet) with [src] "laser" or "manual"; [txt] a text mark's words.
 */
@Serializable
data class MkEl(val id: String, val t: String, val pts: List<List<Float>>, val c: String = "ink", val w: Int = 1, val v: Int? = null, val src: String? = null, val txt: String? = null)

/**
 * A drawing, a photo or a note inside a workspace. A drawing or photo is [W] × [H] units with its marks [els]; a photo's
 * picture is the JPEG file [src] in the app's storage ("photos/<id>.jpg") and may carry a [caption].
 */
@Serializable
data class Item(
    val id: String,
    val kind: String,                    // drawing, photo, note
    val name: String = "",
    val text: String = "",
    val checks: List<Check> = emptyList(),
    val rep: Boolean? = null,            // in the report; null = the kind's default (notes no, the rest yes)
    val created: Long = 0,
    val edited: Long = 0,
    val els: List<MkEl> = emptyList(),
    val src: String? = null,
    val W: Int = 1000,
    val H: Int = 0,
    val caption: String = ""
) {
    val inReport get() = rep ?: (kind != "note")
    /** The height in item units (prototype it.H || (photo ? 750 : 1300)). */
    val hh get() = if (H > 0) H else if (kind == "photo") 750 else 1300
}

/** A reading waiting for the builder's confirmation (prototype dims[k].pending): from the laser ("sim") or typed. */
@Serializable
data class Pending(val mm: Int, val src: String = "sim", val from: String? = null)

/**
 * One measurement in mm. [v] is the confirmed value; [pending] an unconfirmed reading. Status: pending → "recv",
 * v → "conf", else "unset" (prototype dimStatus). [src]: "sim" (laser), "manual" (typed), "default" (thickness only).
 */
@Serializable
data class Dim(val v: Int? = null, val src: String? = null, val pending: Pending? = null) {
    val status get() = when { pending != null -> "recv"; v != null -> "conf"; else -> "unset" }
}

/** A door or window. Offset from the wall's start corner, clockwise, to the near edge; sill from the floor (doors 0). */
@Serializable
data class Opening(
    val id: String,
    val type: String,                    // door, window
    val wall: String,                    // A, B, C, D (or a polygon wall letter)
    val w: Int, val h: Int, val off: Int, val sill: Int = 0,
    val offDrag: Boolean = false,        // position set by dragging: approximate until saved from its sheet
    val sillDrag: Boolean = false
) { val approx get() = offDrag || sillDrag }

/**
 * Something on a wall the furniture must keep clear of: [t] socket, switch, cold, hot, sewer, gas or meter. [off] from
 * the wall's start corner and [h] from the floor, both to its centre, mm. [d] a pipe's diameter or the meter's width,
 * [mh] the meter's height; [src] "manual" or "sim" (the laser).
 */
@Serializable
data class SitePoint(val id: String, val t: String, val wall: String, val off: Int, val h: Int, val d: Int = 0, val mh: Int = 0, val src: String = "manual")

@Serializable
data class Pt(val x: Double, val y: Double)

@Serializable
data class Diag(val id: String, val a: Int, val b: Int)

/** A drawn room: corners in mm keeping the sketch's proportions (not the measured shape), clockwise, first corner top-left. */
@Serializable
data class Poly(val verts: List<Pt>, val diags: List<Diag> = emptyList(), val template: String = "sketch")

@Serializable
data class View3D(val id: String, val img: String, val ts: Long)

/**
 * A room plan (prototype newRoom()). Rectangle: dims A (length, walls A and C), B (width, walls B and D), H (height),
 * T (wall thickness, 200 by default, only used to draw). Polygon: one dim per wall letter plus H, T and diagonals X1….
 */
@Serializable
data class Room(
    val id: String,
    val floorId: String,
    val name: String,
    val template: String = "rect",
    val shape: String = "rect",          // rect, poly
    val dims: Map<String, Dim> = mapOf("A" to Dim(), "B" to Dim(), "H" to Dim(), "T" to Dim(200, "default")),
    val openings: List<Opening> = emptyList(),
    val poly: Poly? = null,
    val rot: Int = 0,                    // plan turned in 90° steps
    val views: List<View3D> = emptyList(),
    val wallColor: String = "#ECE8E1",
    val floorColor: String = "#C49A6C",
    val created: Long = 0,
    /** Furniture orders: sockets, switches, pipes and the gas meter on the walls (furniture plan section 5). */
    val points: List<SitePoint> = emptyList()
) {
    fun dim(k: String) = dims[k] ?: Dim()
    val isPoly get() = shape == "poly" && (poly?.verts?.size ?: 0) >= 3
}

@Serializable
data class Estimate(val materials: List<Row> = emptyList(), val labor: List<Row> = emptyList())

@Serializable
data class Row(val id: String, val name: String = "", val unit: String = "", val qty: String = "", val price: String = "", val amount: String = "")

/**
 * An issued quote: the report as it was, frozen (prototype p.quotes[]: no, ts, sn, fp, total). Later changes to the
 * project make a new quote; this one never changes. [total] is the grand total in the smallest unit, as text.
 */
@Serializable
data class Quote(val no: Int, val ts: Long, val sn: Snap, val fp: String, val total: String)

/** What the PDF shows that the builder can switch off (prototype S.settings.pdf; Profile, part 7). */
@Serializable
data class PdfParts(val plan: Boolean = true, val dims: Boolean = true, val views: Boolean = true, val estimate: Boolean = true, val sign: Boolean = true)

/** A room as it goes into the report: its 3D views already filtered, and its workspace's name in the report language. */
@Serializable
data class SnapRoom(val room: Room, val floorLabel: String)

/** A drawing, photo or note from a workspace, chosen for the report (prototype sn.extras). */
@Serializable
data class SnapExtra(val id: String, val kind: String, val name: String, val ws: String, val text: String = "", val checks: List<Check> = emptyList(), val edited: Long = 0,
                     val els: List<MkEl> = emptyList(), val src: String? = null, val W: Int = 1000, val H: Int = 0, val caption: String = "") {
    /** The drawing or photo as an item, for the shared marks renderer. */
    fun asItem() = Item(id, kind, name, els = els, src = src, W = W, H = H, caption = caption)
}

/** Everything the report pages are drawn from (prototype snapshotOf). A draft builds one each time; a quote keeps its own. */
@Serializable
data class Snap(
    val name: String, val customer: String = "", val phone: String = "", val address: String = "", val location: Location? = null,
    val currency: String = "UZS", val precision: Int = 0, val unit: String = "m", val lang: String = "uz", val notes: String = "",
    val builderName: String = "", val builderPhone: String = "", val pdf: PdfParts = PdfParts(),
    val rooms: List<SnapRoom> = emptyList(), val estimate: Estimate = Estimate(), val extras: List<SnapExtra> = emptyList(),
    /** Furniture orders: the furniture, the materials it uses (names and colours), the price lines and terms. */
    val furniture: List<uz.metrx.app.furniture.Furniture> = emptyList(), val fmats: List<uz.metrx.app.furniture.Mat> = emptyList(),
    val flines: List<SnapLine> = emptyList(), val ftotal: String = "", val fprepay: Int = 50, val fdays: Int = 0, val finst: Int = 0,
    val fhandles: String = "", val fws: uz.metrx.app.furniture.Workshop? = null
)

/** A line of a furniture order's price in the customer's PDF: [key] a furniture id or "deliver". */
@Serializable
data class SnapLine(val key: String, val amount: String)

/** A reading on the Measure page: [src] "sim" (laser) or "manual"; [used] says where it went (a wall or the height). */
@Serializable
data class Reading(val id: String, val n: Int, val mm: Int, val ts: Long, val src: String, val used: String? = null)

/** Short random ids like the prototype's uid(). */
fun uid(): String {
    val chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    return (1..9).map { chars[kotlin.random.Random.nextInt(chars.length)] }.joinToString("")
}
