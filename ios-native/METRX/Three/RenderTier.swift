import Foundation

/*
 * How much the 3D picture does on this phone ("modern furniture 3D" part 1, founder 25 Oct 2026: auto quality, a Sifat
 * override in Profile later). high: 512 px pictures, soft sun shadows, studio reflections; low: 256 px pictures, no
 * shadows, simpler light (no clear coats, duller metal); flat: the old unlit colours, kept as a fallback.
 */

enum Quality3: String {
    case high, low, flat

    /// 512 or 256 px decor pictures.
    var texPx: Int { self == .high ? 512 : 256 }

    /// The quality for this phone now: the Profile setting (AppSettings.quality), else worked out from the phone.
    static func current() -> Quality3 {
        let p = ProcessInfo.processInfo
        if p.arguments.contains("-flat3d") { return .flat }
        return quality3(AppSettings.shared.quality, memory: p.physicalMemory, hot: p.thermalState == .serious || p.thermalState == .critical,
                        model: deviceModel())
    }
}

/// The quality for a setting ("auto", "high", "low", "flat"), the phone's memory in bytes, whether it is running hot and
/// its model ("iPhone13,2"). iPhone 12 and later (iPhone13,x and up, the SE 3 too) are high; iPhone 8 / X and older
/// (iPhone10,x and below) low; the XS / XR / 11 / SE 2 in between by their memory (4 GB high, 3 GB low). A phone
/// running hot, or with under 2.5 GB, is low; anything else (an iPad) goes by memory.
func quality3(_ setting: String, memory: UInt64, hot: Bool, model: String) -> Quality3 {
    if let q = Quality3(rawValue: setting) { return q }
    if hot { return .low }
    let gb = Double(memory) / 1e9
    if gb < 2.5 { return .low }
    if let major = iPhoneMajor(model) {
        if major >= 13 { return .high }
        if major <= 10 { return .low }
    }
    return gb >= 3.5 ? .high : .low
}

/// The model number of an iPhone's identifier ("iPhone12,8" → 12); nil for anything else.
func iPhoneMajor(_ model: String) -> Int? {
    guard model.hasPrefix("iPhone") else { return nil }
    return Int(model.dropFirst(6).prefix { $0.isNumber })
}

/// This device's identifier ("iPhone13,2"); in the simulator, the simulated one's.
func deviceModel() -> String {
    if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
    var u = utsname()
    uname(&u)
    return withUnsafeBytes(of: &u.machine) { raw in
        String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
    }
}

/// The files a decor picture may be in, under tex/, best first: the shared folder's own (512/oak_halifax.webp), the other
/// size, then older spellings (oak_halifax_512.jpg and the like), then one without a size.
func texFiles(_ id: String, _ px: Int) -> [String] {
    let other = px == 512 ? 256 : 512
    var out: [String] = [], names: [String] = []
    for s in [px, other] { out.append("\(s)/\(id).webp") }
    for s in [px, other] { names += ["\(s)/\(id)", "\(id)_\(s)", "\(id)-\(s)", "\(id)@\(s)", "\(id)_\(s)px"] }
    names.append(id)
    for n in names { for e in ["webp", "jpg", "jpeg", "png"] where !out.contains(n + "." + e) { out.append(n + "." + e) } }
    return out
}

/// The pictures in the shared tex/ folder (android-native/app/src/main/assets/tex, 512/ and 256/; SOURCES.md there).
let TEX_FILES: Set<String> = ["oak_halifax", "oak_craft", "walnut", "wenge", "marble_white", "travertine", "stone_dark", "fabric_boucle",
                              "fabric_weave", "floor_planks", "tile_subway", "skinali_print"]

/// A decor's picture: its file under tex/ and the colour its average is recoloured to (nil: as drawn), so one picture
/// serves several decors (Android geo/Look.kt TexInfo.tint).
struct TexSrc: Equatable {
    let file: String
    let avg: Int?
    init(_ file: String, _ avg: Int? = nil) { self.file = file; self.avg = avg }
    var tinted: Bool { avg != nil }
}

/// The picture of a decor id of the data (Mat.tex, PieceLook.swift TEX_IDS), the same table as Android's: Halifax tobacco
/// is the Halifax picture darker and warmer, dark oak the wenge picture lighter, onyx the travertine one a little warmer,
/// velvet and plain fabric the woven one (the look's own colour tints it). A file's own name is itself. nil: no picture
/// (fluted and fluted_glass are drawn as geometry), or an id nothing is known of.
func texSource(_ id: String) -> TexSrc? {
    switch id {
    case "oak_light": return TexSrc("oak_halifax")
    case "oak_tobacco": return TexSrc("oak_halifax", 0x7A5A40)
    case "oak_golden": return TexSrc("oak_craft")
    case "oak_dark": return TexSrc("wenge", 0x5A3F2E)
    case "walnut": return TexSrc("walnut")
    case "wenge": return TexSrc("wenge")
    case "marble_white": return TexSrc("marble_white")
    case "onyx_beige": return TexSrc("travertine", 0xE8DBC2)
    case "stone_dark": return TexSrc("stone_dark")
    case "skinali_print": return TexSrc("skinali_print")
    case "tile_white": return TexSrc("tile_subway")
    case "boucle": return TexSrc("fabric_boucle")
    case "velvet", "fabric": return TexSrc("fabric_weave")
    case "fluted", "fluted_glass": return nil
    default: return TEX_FILES.contains(id) ? TexSrc(id) : nil
    }
}
