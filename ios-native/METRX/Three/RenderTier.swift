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

/// The files a decor picture may be in, under tex/, best first: the size asked for (oak_light_512.jpg and the like), the
/// other size, then one without a size.
func texFiles(_ id: String, _ px: Int) -> [String] {
    let other = px == 512 ? 256 : 512
    var names: [String] = []
    for s in [px, other] { names += ["\(id)_\(s)", "\(id)-\(s)", "\(id)@\(s)", "\(s)/\(id)", "\(id)_\(s)px"] }
    names.append(id)
    var out: [String] = []
    for n in names { for e in ["jpg", "jpeg", "png", "webp"] { out.append(n + "." + e) } }
    return out
}
