import Foundation

/*
 * How this workshop builds and prices (Profile → Ustaxona sozlamalari; furniture plan sections 6.2, 6.7 and 12;
 * Android furniture/Workshop.kt). Every number is a default for the founder's furniture makers to check.
 */

struct Workshop: Codable, Equatable {
    /// Carcass board thickness, mm (16 or 18).
    var t = 16
    /// Back panel "nail" (nailed on, 2 mm in from each edge) or "groove" (sits 8 mm into grooves).
    var back = "nail"
    /// Gap between fronts and at the outer edges, tenths of a mm (3 mm, 1,5 mm).
    var gap10 = 30
    var edge10 = 15
    /// Thick (visible) edge banding, tenths of a mm; cut sizes are the finished size less this on each thick edge.
    var band10 = 20
    var bandOff = true
    /// Sheet, saw cut and the trimmed strip on each sheet edge, mm.
    var sheetL = 2800
    var sheetW = 2070
    var kerf = 4
    var trim = 10
    /// Legs under base and tall units, mm.
    var legH = 100
    /// Customer price: margin %, prepayment %.
    var margin = 30
    var prepay = 50
    /// Labour rates in the smallest money unit: per sheet cut, per metre banded, per module assembled; installation and delivery per order.
    var rCut = "45000"
    var rBand = "3000"
    var rAsm = "120000"
    var rInstall = "1500000"
    var rDeliver = "300000"
    /// Remnants (Advanced): offcuts at least this many mm each way are kept for the next orders.
    var remMin = REM_MIN
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        t = c.v(.t, 16); back = c.v(.back, "nail"); gap10 = c.v(.gap10, 30); edge10 = c.v(.edge10, 15); band10 = c.v(.band10, 20); bandOff = c.v(.bandOff, true)
        sheetL = c.v(.sheetL, 2800); sheetW = c.v(.sheetW, 2070); kerf = c.v(.kerf, 4); trim = c.v(.trim, 10); legH = c.v(.legH, 100)
        margin = c.v(.margin, 30); prepay = c.v(.prepay, 50)
        rCut = c.v(.rCut, "45000"); rBand = c.v(.rBand, "3000"); rAsm = c.v(.rAsm, "120000"); rInstall = c.v(.rInstall, "1500000"); rDeliver = c.v(.rDeliver, "300000")
        remMin = c.v(.remMin, REM_MIN)
    }
}

/// A board or banding in the workshop's list. kind board (carcass/fronts), back, worktop (priced by the running metre),
/// band; t thickness, mm (banding: tenths, 20 = 2 mm); a sheet's l × w; price per sheet, or per metre for banding and
/// worktops, smallest unit; grain keeps parts along the sheet's length; rgb for drawings and 3D.
/// Added 25 Oct 2026 (Android furniture/Workshop.kt), and written only when set (a list saved before, and an issued
/// quote's materials, stay as they were): finish how the 3D shows it, "gloss", "matte", "wood", "stone" or "glass" ("" a
/// plain board, matte); tex the texture id the 3D draws it with (PieceLook.swift TEX_IDS; nil: its colour only); per
/// "m2" when price is per m² of its parts (fronts bought by the m²; a backsplash by its area) instead of per sheet or
/// per metre.
struct Mat: Codable, Equatable, Identifiable {
    var id: String, kind: String, name: String, t: Int
    var l = 2800, w = 2070
    var price = ""
    var grain = false
    var rgb = "#F5F5F2"
    var preset = false
    var finish = ""
    /// The decor picture of the lit 3D (Geo/Look.swift: a file under tex/, e.g. "oak_light"); nil a plain colour.
    var tex: String? = nil
    var per = ""
    /// Priced by the m² of its parts (a backsplash: of its area).
    var byArea: Bool { per == "m2" }
    init(_ id: String, _ kind: String, _ name: String, _ t: Int, l: Int = 2800, w: Int = 2070, price: String = "", grain: Bool = false, rgb: String = "#F5F5F2", preset: Bool = false,
         finish: String = "", tex: String? = nil, per: String = "") {
        self.id = id; self.kind = kind; self.name = name; self.t = t; self.l = l; self.w = w; self.price = price; self.grain = grain; self.rgb = rgb; self.preset = preset
        self.finish = finish; self.tex = tex; self.per = per
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = c.v(.kind, "board"); name = c.v(.name, ""); t = c.v(.t, 16)
        l = c.v(.l, 2800); w = c.v(.w, 2070); price = c.v(.price, ""); grain = c.v(.grain, false); rgb = c.v(.rgb, "#F5F5F2"); preset = c.v(.preset, false)
        finish = c.v(.finish, ""); tex = (try? c.decodeIfPresent(String.self, forKey: .tex)) ?? nil; per = c.v(.per, "")
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case id, kind, name, t, l, w, price, grain, rgb, preset, finish, tex, per }
    /// The synthesized form, with finish, tex and per written only when set.
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(kind, forKey: .kind); try c.encode(name, forKey: .name); try c.encode(t, forKey: .t)
        try c.encode(l, forKey: .l); try c.encode(w, forKey: .w); try c.encode(price, forKey: .price); try c.encode(grain, forKey: .grain)
        try c.encode(rgb, forKey: .rgb); try c.encode(preset, forKey: .preset)
        if !finish.isEmpty { try c.encode(finish, forKey: .finish) }
        try c.encodeIfPresent(tex, forKey: .tex)
        if !per.isEmpty { try c.encode(per, forKey: .per) }
    }
}

/// A hardware item: kind says what the core counts it as; price per piece (per metre for rails, per pair for runners).
struct Hw: Codable, Equatable, Identifiable {
    var id: String, kind: String, name: String
    var price = ""
    var preset = false
    init(_ id: String, _ kind: String, _ name: String, _ price: String = "", _ preset: Bool = false) { self.id = id; self.kind = kind; self.name = name; self.price = price; self.preset = preset }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = c.v(.kind, "handle"); name = c.v(.name, ""); price = c.v(.price, ""); preset = c.v(.preset, false)
    }
}

/// The lists a new workshop starts with (design canvas screen 13); prices are samples for the makers to replace.
let MAT_PRESETS: [Mat] = [
    Mat("ldsp16w", "board", "LDSP 16 · Oq", 16, price: "620000", rgb: "#F5F5F2", preset: true),
    Mat("ldsp16k", "board", "LDSP 16 · Kashmir", 16, price: "690000", grain: true, rgb: "#CDBFAE", preset: true),
    Mat("ldsp18a", "board", "LDSP 18 · Antratsit", 18, price: "720000", rgb: "#4B4F58", preset: true),
    Mat("mdf18", "board", "MDF 18 · bo‘yalgan", 18, price: "980000", rgb: "#E8E4DC", preset: true),
    // bathrooms (22 Oct 2026): moisture-resistant board for vanities, mirror cabinets and tall cabinets
    Mat("ldsp16mr", "board", "LDSP 16 · namga chidamli", 16, price: "780000", rgb: "#EEF0EC", preset: true),
    Mat("hdf3", "back", "DVP 3,2 · Oq", 3, price: "210000", rgb: "#FFFFFF", preset: true),
    Mat("wt38", "worktop", "Stoleshnitsa 38 · Antratsit", 38, l: 4100, w: 600, price: "360000", rgb: "#4B4F58", preset: true),
    Mat("splash6", "splash", "Stenovaya panel 6 mm (fartuk)", 6, l: 4100, w: 600, price: "190000", rgb: "#E8E2D8", preset: true),
    Mat("band2", "band", "Kromka PVX 2 mm", 20, l: 0, w: 0, price: "4500", preset: true),
    Mat("band04", "band", "Kromka PVX 0,4 mm", 4, l: 0, w: 0, price: "1500", preset: true)
] + DECOR_PRESETS

/// The handle presets beyond the usual skoba: offered for a whole order, never the usual price.
let HANDLE_MORE: Set<String> = ["handleLong", "handleKnob", "handle640", "handle1024"]

let HW_PRESETS: [Hw] = [
    Hw("hingeSoft", "hingeSoft", "Petlya, yumshoq yopilish", "18000", true),
    Hw("hinge", "hinge", "Petlya, oddiy", "9000", true),
    Hw("runner", "runner", "Yo‘naltiruvchi 300–600", "95000", true),
    Hw("handle", "handle", "Tutqich skoba 128", "25000", true),
    // more handles to pick for a whole order ("Change for all", 23 Oct 2026); the price stays the skoba's otherwise
    Hw("handleLong", "handle", "Tutqich uzun 320", "45000", true),
    Hw("handleKnob", "handle", "Tutqich knopka", "15000", true),
    // a door or drawer without a handle opens by a push latch (tip-on), 25 Oct 2026
    Hw("push", "push", "Bosib ochish mexanizmi (tip-on)", "30000", true),
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
    Hw("glassDoor", "glassDoor", "Shisha eshik, alyumin ramka (m²)", "900000", true),
    // the design options (modern 3D part 2, 25 Oct 2026; PieceLook.swift): samples, sources in design/furniture/uz-market-research.md
    Hw("handle640", "handle", "Tutqich uzun 640 (vertikal)", "85000", true),
    Hw("handle1024", "handle", "Tutqich uzun 1024 (vertikal)", "130000", true),
    Hw("gola", "gola", "Gola profili (metr)", "150000", true),
    Hw("frontShaker", "frontShaker", "Frezerli fasad, neoklassika (m²)", "100000", true),
    Hw("frontFluted", "frontFluted", "Reykali (rifli) fasad (m²)", "250000", true),
    Hw("legMetal", "legMetal", "Metall oyoq, ko‘rinadigan", "45000", true),
    Hw("ceilUnit", "ceilUnit", "Shiftgacha modullar qatori (metr)", "800000", true),
    Hw("wdCeil", "wdCeil", "Shkaf ustida shiftgacha qism (metr)", "800000", true),
    Hw("fglass", "fglass", "Rifli shisha, vitrina (m²)", "450000", true),
    Hw("waterfall", "waterfall", "Orol stoleshnitsasining sharshara uchi", "1200000", true),
    Hw("mirrorBronze", "mirrorBronze", "Oyna bronza 4 mm (m²)", "350000", true),
    Hw("mirrorGraphite", "mirrorGraphite", "Oyna grafit 4 mm (m²)", "350000", true),
    Hw("ledSensor", "ledSensor", "LED eshik datchigi", "60000", true),
    Hw("headSoft", "headSoft", "Yumshoq bosh qism (m²)", "900000", true),
    Hw("headTufted", "headTufted", "Karetka tikuvli bosh qism (m²)", "1300000", true),
    Hw("softPanel", "softPanel", "Yumshoq devor paneli (m²)", "750000", true),
    // the gorka's TV panel facing (modern 3D part 6a): samples for the makers to replace
    Hw("tvStone", "tvStone", "TV panel, tosh ko‘rinishli plita (m²)", "450000", true),
    Hw("tvSlats", "tvSlats", "TV panel, yog‘och reykalar (m²)", "550000", true),
    Hw("tvMould", "tvMould", "TV panel, frezerli MDF (m²)", "300000", true)
]
