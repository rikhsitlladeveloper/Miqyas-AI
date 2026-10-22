package uz.metrx.app.core

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.builtins.serializer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Laser connection states, as in the prototype. The laser itself is simulated until a real device is verified. */
enum class Laser { DISCONNECTED, SEARCHING, FOUND, CONNECTED }

/**
 * Small app-wide settings kept in SharedPreferences: language, first-run state, the builder's name and phone,
 * the visit counter for the greeting line, and the theme. Projects get their own database in part 2.
 */
class Settings(context: Context) {
    private val p: SharedPreferences = context.getSharedPreferences("metrx", Context.MODE_PRIVATE)

    var lang by mutableStateOf(Lang.of(p.getString("lang", null)))
        private set
    var firstRunDone by mutableStateOf(p.getBoolean("firstRunDone", false))
        private set
    var builderName by mutableStateOf(p.getString("builderName", "") ?: "")
        private set
    var builderPhone by mutableStateOf(p.getString("builderPhone", "") ?: "")
        private set
    var dark by mutableStateOf(p.getBoolean("dark", false))
        private set
    /**
     * "build" or "furniture", chosen after sign-in (furniture plan section 3); null until then. People who started
     * the app before industries existed are builders.
     */
    var industry by mutableStateOf(p.getString("industry", null) ?: if (p.getBoolean("firstRunDone", false)) "build" else null)
        private set
    val furniture get() = industry == "furniture"
    /** A tiler: own home, orders and tile layouts (tiles/Tiles.kt). */
    val tiler get() = industry == "tiler"
    /** An electrician: own home, orders, devices and cable routes (elec/Elec.kt). */
    val elec get() = industry == "elec"
    /** A plumber: own home, orders, fixtures, pipes and heating (plumb/Plumb.kt). */
    val plumb get() = industry == "plumb"
    /** A windows-and-doors maker: own home, orders, products fitted in the openings (win/Win.kt). */
    val win get() = industry == "win"
    fun setIndustryKind(v: String) { industry = v; p.edit().putString("industry", v).apply() }
    /** A furniture maker's prices, order stages, workshop rules and cutting lists (Profile → Advanced); off, the app is just the 3D design. */
    var advanced by mutableStateOf(p.getBoolean("advanced", false)); private set
    fun setAdvancedOn(v: Boolean) { advanced = v; p.edit().putBoolean("advanced", v).apply() }

    // declared before the first property that decodes with it (trade, workshop), or it is still null there
    private val js = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; encodeDefaults = true }

    /** The trades' calculator: options and prices (trades/Trades.kt), one set for all. */
    var trade by mutableStateOf(runCatching { js.decodeFromString(uz.metrx.app.trades.TradeSet.serializer(), p.getString("tradeSet", null) ?: "{}") }.getOrDefault(uz.metrx.app.trades.TradeSet()))
        private set
    fun setTradeSet(v: uz.metrx.app.trades.TradeSet) { trade = v; p.edit().putString("tradeSet", js.encodeToString(uz.metrx.app.trades.TradeSet.serializer(), v)).apply() }

    /** Furniture makers: how the workshop builds and prices, and its boards and hardware (furniture plan sections 6.2, 6.6). */
    var workshop by mutableStateOf(runCatching { js.decodeFromString(uz.metrx.app.furniture.Workshop.serializer(), p.getString("workshop", null) ?: "{}") }.getOrDefault(uz.metrx.app.furniture.Workshop()))
        private set
    fun setWorkshopRules(v: uz.metrx.app.furniture.Workshop) { workshop = v; p.edit().putString("workshop", js.encodeToString(uz.metrx.app.furniture.Workshop.serializer(), v)).apply() }
    private val matSer = kotlinx.serialization.builtins.ListSerializer(uz.metrx.app.furniture.Mat.serializer())
    private val hwSer = kotlinx.serialization.builtins.ListSerializer(uz.metrx.app.furniture.Hw.serializer())
    // a saved list gets the presets added since it was saved (the worktop came with part 4)
    var mats: List<uz.metrx.app.furniture.Mat> by mutableStateOf((p.getString("mats", null)?.let { runCatching { js.decodeFromString(matSer, it) }.getOrNull() } ?: emptyList())
        .let { saved -> saved + uz.metrx.app.furniture.MAT_PRESETS.filter { pr -> saved.none { it.id == pr.id } } })
        private set
    var hws: List<uz.metrx.app.furniture.Hw> by mutableStateOf((p.getString("hws", null)?.let { runCatching { js.decodeFromString(hwSer, it) }.getOrNull() } ?: emptyList())
        .let { saved -> saved + uz.metrx.app.furniture.HW_PRESETS.filter { pr -> saved.none { it.id == pr.id } } })
        private set
    fun setMatList(v: List<uz.metrx.app.furniture.Mat>) { mats = v; p.edit().putString("mats", js.encodeToString(matSer, v)).apply() }
    fun setHwList(v: List<uz.metrx.app.furniture.Hw>) { hws = v; p.edit().putString("hws", js.encodeToString(hwSer, v)).apply() }
    /** Currency and report language that new projects start with (Profile settings in the prototype). */
    var currency by mutableStateOf(p.getString("currency", "UZS") ?: "UZS")
        private set
    var reportLang by mutableStateOf(Lang.of(p.getString("reportLang", null) ?: p.getString("lang", null)))
        private set

    /** Lengths in metres or centimetres (Profile, part 7); 90°/45° snapping for drawn rooms. */
    var unit by mutableStateOf(if (p.getString("unit", "m") == "cm") uz.metrx.app.geo.LenUnit.CM else uz.metrx.app.geo.LenUnit.M)
        private set
    var angleSnap by mutableStateOf(p.getBoolean("angleSnap", true))
        private set
    /** "Don't show again" for the editor's first-time tip. */
    var editorTipOff by mutableStateOf(p.getBoolean("tipEditor", false))
        private set
    /** Default door and window sizes (Profile → Eshik va deraza o‘lchamlari), mm. */
    var doorW by mutableIntStateOf(p.getInt("doorW", 900)); private set
    var doorH by mutableIntStateOf(p.getInt("doorH", 2100)); private set
    var winW by mutableIntStateOf(p.getInt("winW", 1200)); private set
    var winH by mutableIntStateOf(p.getInt("winH", 1500)); private set
    var winSill by mutableIntStateOf(p.getInt("winSill", 900)); private set
    fun setDefaults(dw: Int, dh: Int, ww: Int, wh: Int, ws: Int) {
        doorW = dw; doorH = dh; winW = ww; winH = wh; winSill = ws
        p.edit().putInt("doorW", dw).putInt("doorH", dh).putInt("winW", ww).putInt("winH", wh).putInt("winSill", ws).apply()
    }
    /** What the PDF shows (Profile → PDF tarkibi); applies to new reports and quotes. */
    var pdf by mutableStateOf(runCatching { kotlinx.serialization.json.Json.decodeFromString(uz.metrx.app.data.PdfParts.serializer(), p.getString("pdf", null) ?: "{}") }.getOrDefault(uz.metrx.app.data.PdfParts()))
        private set
    fun setPdfParts(v: uz.metrx.app.data.PdfParts) { pdf = v; p.edit().putString("pdf", kotlinx.serialization.json.Json.encodeToString(uz.metrx.app.data.PdfParts.serializer(), v)).apply() }
    /** What a plan shows in the middle of a room: "both" name and area, "name", "area" or "none" (prototype roomLabel). */
    var roomLabel by mutableStateOf(p.getString("roomLabel", "both") ?: "both"); private set
    fun setRoomLabelMode(v: String) { roomLabel = v; p.edit().putString("roomLabel", v).apply() }
    /** First-time tips come back (prototype hintsReset). */
    fun resetHints() { editorTipOff = false; p.edit().putBoolean("tipEditor", false).apply() }
    fun setReportLangDefault(l: Lang) { reportLang = l; p.edit().putString("reportLang", l.code).apply() }

    /** One visit = one cold start; the Home greeting line changes with it. */
    val visit: Int = (p.getInt("visit", -1) + 1).also { p.edit().putInt("visit", it).apply() }

    /** Simulated laser state; not saved, a new start begins disconnected like a real Bluetooth device. */
    var laser by mutableStateOf(Laser.DISCONNECTED)
    var laserTick by mutableIntStateOf(0)

    /**
     * Estimate rows typed but not saved (prototype S.rowDrafts), by "project|mat or lab|row id or new":
     * the sheet's fields, kept when the sheet is left without saving, brought back when it opens again.
     */
    private val draftSer = kotlinx.serialization.builtins.MapSerializer(String.serializer(), kotlinx.serialization.builtins.MapSerializer(String.serializer(), String.serializer()))
    var rowDrafts: Map<String, Map<String, String>> by mutableStateOf(runCatching { kotlinx.serialization.json.Json.decodeFromString(draftSer, p.getString("rowDrafts", null) ?: "{}") }.getOrDefault(emptyMap()))
        private set
    fun setDraft(key: String, form: Map<String, String>?) {
        rowDrafts = if (form == null) rowDrafts - key else rowDrafts + (key to form)
        p.edit().putString("rowDrafts", kotlinx.serialization.json.Json.encodeToString(draftSer, rowDrafts)).apply()
    }

    /** Laser and typed readings of the Measure page, oldest first (prototype S.readings); not tied to a project. */
    var readings: List<uz.metrx.app.data.Reading> by mutableStateOf(runCatching { kotlinx.serialization.json.Json.decodeFromString(kotlinx.serialization.builtins.ListSerializer(uz.metrx.app.data.Reading.serializer()), p.getString("readings", null) ?: "[]") }.getOrDefault(emptyList()))
        private set
    private fun saveReadings() { p.edit().putString("readings", kotlinx.serialization.json.Json.encodeToString(kotlinx.serialization.builtins.ListSerializer(uz.metrx.app.data.Reading.serializer()), readings)).apply() }
    fun addReading(mm: Int, src: String): uz.metrx.app.data.Reading {
        val r = uz.metrx.app.data.Reading(uz.metrx.app.data.uid(), (readings.maxOfOrNull { it.n } ?: 0) + 1, mm, System.currentTimeMillis(), src)
        readings = readings + r; saveReadings(); return r
    }
    fun deleteReading(id: String) { readings = readings.filter { it.id != id }; saveReadings() }
    fun markReadingUsed(id: String, where: String) { readings = readings.map { if (it.id == id) it.copy(used = where) else it }; saveReadings() }
    /** The brick tool's brick, joint and spare (prototype S.settings.brick). */
    var brick by mutableStateOf(runCatching { kotlinx.serialization.json.Json.decodeFromString(uz.metrx.app.core.BrickSpec.serializer(), p.getString("brick", null) ?: "{}") }.getOrDefault(uz.metrx.app.core.BrickSpec()))
        private set
    fun setBrickSpec(b: uz.metrx.app.core.BrickSpec) { brick = b; p.edit().putString("brick", kotlinx.serialization.json.Json.encodeToString(uz.metrx.app.core.BrickSpec.serializer(), b)).apply() }

    /** Pictures taken on the Measure page, newest first (prototype S.shots): photos that belong to no project yet. */
    private val shotSer = kotlinx.serialization.builtins.ListSerializer(uz.metrx.app.data.Item.serializer())
    var shots: List<uz.metrx.app.data.Item> by mutableStateOf(runCatching { kotlinx.serialization.json.Json.decodeFromString(shotSer, p.getString("shots", null) ?: "[]") }.getOrDefault(emptyList()))
        private set
    fun saveShots(v: List<uz.metrx.app.data.Item>) { shots = v; p.edit().putString("shots", kotlinx.serialization.json.Json.encodeToString(shotSer, v)).apply() }

    fun setLanguage(l: Lang) {
        // as in the prototype, choosing the app language also sets the report language
        lang = l; reportLang = l
        p.edit().putString("lang", l.code).putString("reportLang", l.code).apply()
    }
    fun setCurrencyDefault(c: String) { currency = c; p.edit().putString("currency", c).apply() }
    fun changeUnit(u: uz.metrx.app.geo.LenUnit) { unit = u; p.edit().putString("unit", if (u == uz.metrx.app.geo.LenUnit.CM) "cm" else "m").apply() }
    fun setSnap(on: Boolean) { angleSnap = on; p.edit().putBoolean("angleSnap", on).apply() }
    fun hideEditorTip() { editorTipOff = true; p.edit().putBoolean("tipEditor", true).apply() }
    fun setDarkMode(on: Boolean) { dark = on; p.edit().putBoolean("dark", on).apply() }
    fun saveBuilder(name: String, phone: String) {
        builderName = name.trim(); builderPhone = Phone.digits(phone)
        p.edit().putString("builderName", builderName).putString("builderPhone", builderPhone).apply()
    }
    fun finishFirstRun() { firstRunDone = true; p.edit().putBoolean("firstRunDone", true).apply() }
}

/** Uzbek phone numbers: 9 digits after +998, shown as 90 123 45 67. */
object Phone {
    fun digits(v: String?): String {
        val d = (v ?: "").filter { it.isDigit() }
        return if (d.length == 12 && d.startsWith("998")) d.substring(3) else d
    }
    fun groups(v: String?): String {
        val d = digits(v)
        return listOf(0 to 2, 2 to 5, 5 to 7, 7 to 9).mapNotNull { (a, b) -> if (d.length > a) d.substring(a, minOf(b, d.length)) else null }
            .joinToString(" ")
    }
    fun format(v: String?): String { val d = digits(v); return if (d.isEmpty()) "" else "+998 " + groups(d) }
    /** null when fine, otherwise the strings key of the error. */
    fun errorKey(v: String?, required: Boolean): String? {
        val d = digits(v)
        if (d.isEmpty()) return if (required) "ph.req" else null
        return if (d.length != 9) "ph.len" else null
    }
}

/** Number formats of the prototype: comma decimals and space groups, except English (point and comma). */
object Num {
    fun dec(l: Lang) = if (l == Lang.EN) '.' else ','
    /** Lengths are stored in millimetres and shown in metres with 2 decimals (3 when the value needs it). */
    fun len(mm: Int, l: Lang): String {
        val digits = if (mm % 10 != 0) 3 else 2
        return String.format(java.util.Locale.ROOT, "%.${digits}f", mm / 1000.0).replace('.', dec(l))
    }
    fun fixed(v: Double, decimals: Int, l: Lang) = String.format(java.util.Locale.ROOT, "%.${decimals}f", v).replace('.', dec(l))
}
