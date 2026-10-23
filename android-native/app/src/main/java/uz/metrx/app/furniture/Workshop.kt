package uz.metrx.app.furniture

import kotlinx.serialization.Serializable

/*
 * How this workshop builds and prices (Profile → Ustaxona sozlamalari; furniture plan sections 6.2, 6.7 and 12). Every
 * number is a default for the founder's furniture makers to check.
 */

@Serializable
data class Workshop(
    /** Carcass board thickness, mm (16 or 18). */
    val t: Int = 16,
    /** Back panel "nail" (nailed on, 2 mm in from each edge) or "groove" (sits 8 mm into grooves). */
    val back: String = "nail",
    /** Gap between fronts and at the outer edges, tenths of a mm (3 mm, 1,5 mm). */
    val gap10: Int = 30,
    val edge10: Int = 15,
    /** Thick (visible) edge banding, tenths of a mm; cut sizes are the finished size less this on each thick edge. */
    val band10: Int = 20,
    val bandOff: Boolean = true,
    /** Sheet, saw cut and the trimmed strip on each sheet edge, mm. */
    val sheetL: Int = 2800,
    val sheetW: Int = 2070,
    val kerf: Int = 4,
    val trim: Int = 10,
    /** Legs under base and tall units, mm. */
    val legH: Int = 100,
    /** Customer price: margin %, prepayment %. */
    val margin: Int = 30,
    val prepay: Int = 50,
    /** Labour rates in the smallest money unit: per sheet cut, per metre banded, per module assembled; installation and delivery per order. */
    val rCut: String = "45000",
    val rBand: String = "3000",
    val rAsm: String = "120000",
    val rInstall: String = "1500000",
    val rDeliver: String = "300000",
    /** Remnants (Advanced): offcuts at least this many mm each way are kept for the next orders. */
    val remMin: Int = REM_MIN
)

/**
 * A board or banding in the workshop's list. [kind] board (carcass/fronts), back, worktop (priced by the running metre), band; [t] thickness, mm (banding:
 * tenths, 20 = 2 mm); a sheet's [l] × [w]; [price] per sheet, or per metre for banding and worktops, smallest unit; [grain] keeps parts
 * along the sheet's length; [rgb] for drawings and 3D.
 */
@Serializable
data class Mat(val id: String, val kind: String, val name: String, val t: Int, val l: Int = 2800, val w: Int = 2070,
               val price: String = "", val grain: Boolean = false, val rgb: String = "#F5F5F2", val preset: Boolean = false)

/** A hardware item: [kind] says what the core counts it as; [price] per piece (per metre for rails, per pair for runners). */
@Serializable
data class Hw(val id: String, val kind: String, val name: String, val price: String = "", val preset: Boolean = false)

/** The lists a new workshop starts with (design canvas screen 13); prices are samples for the makers to replace. */
val MAT_PRESETS = listOf(
    Mat("ldsp16w", "board", "LDSP 16 · Oq", 16, price = "620000", rgb = "#F5F5F2", preset = true),
    Mat("ldsp16k", "board", "LDSP 16 · Kashmir", 16, price = "690000", grain = true, rgb = "#CDBFAE", preset = true),
    Mat("ldsp18a", "board", "LDSP 18 · Antratsit", 18, price = "720000", rgb = "#4B4F58", preset = true),
    Mat("mdf18", "board", "MDF 18 · bo‘yalgan", 18, price = "980000", rgb = "#E8E4DC", preset = true),
    // bathrooms (22 Oct 2026): moisture-resistant board for vanities, mirror cabinets and tall cabinets
    Mat("ldsp16mr", "board", "LDSP 16 · namga chidamli", 16, price = "780000", rgb = "#EEF0EC", preset = true),
    Mat("hdf3", "back", "DVP 3,2 · Oq", 3, price = "210000", rgb = "#FFFFFF", preset = true),
    Mat("wt38", "worktop", "Stoleshnitsa 38 · Antratsit", 38, 4100, 600, price = "360000", rgb = "#4B4F58", preset = true),
    Mat("splash6", "splash", "Stenovaya panel 6 mm (fartuk)", 6, 4100, 600, price = "190000", rgb = "#E8E2D8", preset = true),
    Mat("band2", "band", "Kromka PVX 2 mm", 20, 0, 0, price = "4500", preset = true),
    Mat("band04", "band", "Kromka PVX 0,4 mm", 4, 0, 0, price = "1500", preset = true)
)

/** The handle presets beyond the usual skoba: offered for a whole order, never the usual price. */
val HANDLE_MORE = setOf("handleLong", "handleKnob")

val HW_PRESETS = listOf(
    Hw("hingeSoft", "hingeSoft", "Petlya, yumshoq yopilish", "18000", true),
    Hw("hinge", "hinge", "Petlya, oddiy", "9000", true),
    Hw("runner", "runner", "Yo‘naltiruvchi 300–600", "95000", true),
    Hw("handle", "handle", "Tutqich skoba 128", "25000", true),
    // more handles to pick for a whole order ("Change for all", 23 Oct 2026); the price stays the skoba's otherwise
    Hw("handleLong", "handle", "Tutqich uzun 320", "45000", true),
    Hw("handleKnob", "handle", "Tutqich knopka", "15000", true),
    Hw("leg", "leg", "Oyoq 100 mm", "6000", true),
    Hw("pin", "pin", "Polka ushlagich", "300", true),
    Hw("rail", "rail", "Shtanga (metr)", "35000", true),
    Hw("railEnd", "railEnd", "Shtanga ushlagich", "4000", true),
    Hw("confirmat", "confirmat", "Konfirmat 7 × 50", "250", true),
    Hw("hanger", "hanger", "Osma (yuqori modul)", "12000", true),
    Hw("lift", "lift", "Lift (pantograf)", "450000", true),
    // sliding doors (plan 1b-2)
    Hw("slideTrack", "slideTrack", "Kupe relsi, yuqori + pastki (metr)", "60000", true),
    Hw("slideV", "slideV", "Kupe vertikal profili (metr)", "70000", true),
    Hw("slideH", "slideH", "Kupe gorizontal profili (metr)", "45000", true),
    Hw("slideRoller", "slideRoller", "Kupe rolik to‘plami (eshik)", "85000", true),
    Hw("mirror", "mirror", "Oyna 4 mm (m²)", "250000", true),
    Hw("glass", "glass", "Lakobel shisha (m²)", "320000", true),
    // kitchen extras (plan 1b-1)
    Hw("wtJoint", "wtJoint", "Stoleshnitsa ulash, to‘g‘ri (burchak)", "60000", true),
    Hw("wtMitre", "wtMitre", "Stoleshnitsa ulash, 45° (burchak)", "150000", true),
    Hw("wtCut", "wtCut", "Stoleshnitsada o‘yiq (moyka, plita)", "50000", true),
    Hw("wtEnd", "wtEnd", "Stoleshnitsa uchi (planka)", "15000", true),
    Hw("plinthK", "plinthK", "Tsokol paneli (metr)", "55000", true),
    Hw("plinthCorner", "plinthCorner", "Tsokol burchagi", "12000", true),
    Hw("cornice", "cornice", "Karniz (metr)", "65000", true),
    Hw("led", "led", "LED lenta (metr)", "35000", true),
    Hw("ledPsu", "ledPsu", "LED bloki (5 m gacha)", "120000", true),
    // beds, tables, the bar counter, hallway panels and vitrinas (22 Oct 2026)
    Hw("bedBase", "bedBase", "Ortopedik asos (lamel)", "450000", true),
    Hw("bedLift", "bedLift", "Ko‘tarish mexanizmi (karavot)", "950000", true),
    Hw("tableLeg", "tableLeg", "Stol oyog‘i, metall", "60000", true),
    Hw("tableFrame", "tableFrame", "Stol metall ramkasi (juft)", "450000", true),
    Hw("barRail", "barRail", "Bar oyoq trubasi (metr)", "120000", true),
    Hw("hook", "hook", "Kiyim ilgagi", "15000", true),
    Hw("clip", "clip", "Oyna ushlagichi", "5000", true),
    Hw("glassShelf", "glassShelf", "Shisha tokcha 6 mm (m²)", "300000", true),
    Hw("glassDoor", "glassDoor", "Shisha eshik, alyumin ramka (m²)", "900000", true)
)
