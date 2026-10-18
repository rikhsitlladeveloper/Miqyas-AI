import Foundation
import Observation

/// Laser connection states, as in the prototype. The laser itself is simulated until a real device is verified.
enum Laser { case disconnected, searching, found, connected }

/// Small app-wide settings kept in UserDefaults: language, first-run state, the builder's name and phone, the visit
/// counter for the greeting line, the theme and the Profile settings. Screens read them directly and follow changes.
@Observable
final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let d = UserDefaults.standard

    private(set) var lang: Lang
    private(set) var firstRunDone: Bool
    private(set) var builderName: String
    private(set) var builderPhone: String
    private(set) var dark: Bool
    /// "build" or "furniture", chosen after sign-in (furniture plan section 3); nil until then. People who started the
    /// app before industries existed are builders.
    private(set) var industry: String?
    var furniture: Bool { industry == "furniture" }
    /// Currency and report language that new projects start with.
    private(set) var currency: String
    private(set) var reportLang: Lang
    /// Lengths in metres or centimetres; 90°/45° snapping for drawn rooms.
    private(set) var unitCm: Bool
    private(set) var angleSnap: Bool
    var unit: LenUnit { unitCm ? .cm : .m }
    /// "Don't show again" for the editor's first-time tip.
    private(set) var editorTipOff: Bool
    /// What a plan shows in the middle of a room: "both", "name", "area" or "none".
    private(set) var roomLabel: String
    /// Default door and window sizes, mm.
    private(set) var doorW: Int
    private(set) var doorH: Int
    private(set) var winW: Int
    private(set) var winH: Int
    private(set) var winSill: Int
    /// One visit = one cold start; the Home greeting line changes with it.
    let visit: Int
    /// Laser and typed readings of the Measure page, oldest first (prototype S.readings); not tied to a project.
    private(set) var readings: [Reading]
    /// The brick tool's brick, joint and spare (prototype S.settings.brick).
    private(set) var brick: BrickSpec
    /// Pictures taken on the Measure page, newest first (prototype S.shots): photos that belong to no project yet.
    private(set) var shots: [Item]
    /// What the PDF shows (Profile → PDF; prototype S.settings.pdf).
    private(set) var pdf: PdfParts
    /// Estimate rows typed but not saved (prototype S.rowDrafts), by "project|mat or lab|row id or new": the sheet's
    /// fields, kept when the sheet is left without saving, brought back when it opens again.
    private(set) var rowDrafts: [String: [String: String]]
    /// Simulated laser state; not saved, a new start begins disconnected like a real Bluetooth device.
    var laser: Laser = .disconnected

    private init() {
        // the screen tests start from a clean first run
        if ProcessInfo.processInfo.arguments.contains("-uiReset") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "uz.metrx.app")
        }
        let d = UserDefaults.standard
        if let l = ProcessInfo.processInfo.environment["UI_LANG"] { d.set(l, forKey: "lang"); d.set(l, forKey: "reportLang") }
        lang = Lang.of(d.string(forKey: "lang"))
        firstRunDone = d.bool(forKey: "firstRunDone")
        builderName = d.string(forKey: "builderName") ?? ""
        builderPhone = d.string(forKey: "builderPhone") ?? ""
        dark = d.bool(forKey: "dark")
        industry = d.string(forKey: "industry") ?? (d.bool(forKey: "firstRunDone") ? "build" : nil)
        currency = d.string(forKey: "currency") ?? "UZS"
        reportLang = Lang.of(d.string(forKey: "reportLang") ?? d.string(forKey: "lang"))
        unitCm = d.string(forKey: "unit") == "cm"
        angleSnap = d.object(forKey: "angleSnap") as? Bool ?? true
        editorTipOff = d.bool(forKey: "tipEditor")
        roomLabel = d.string(forKey: "roomLabel") ?? "both"
        func int(_ k: String, _ v: Int) -> Int { d.object(forKey: k) as? Int ?? v }
        doorW = int("doorW", 900); doorH = int("doorH", 2100); winW = int("winW", 1200); winH = int("winH", 1500); winSill = int("winSill", 900)
        readings = d.data(forKey: "readings").flatMap { try? JSONDecoder().decode([Reading].self, from: $0) } ?? []
        brick = d.data(forKey: "brick").flatMap { try? JSONDecoder().decode(BrickSpec.self, from: $0) } ?? BrickSpec()
        shots = d.data(forKey: "shots").flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
        pdf = d.data(forKey: "pdf").flatMap { try? JSONDecoder().decode(PdfParts.self, from: $0) } ?? PdfParts()
        rowDrafts = (d.data(forKey: "rowDrafts")).flatMap { try? JSONDecoder().decode([String: [String: String]].self, from: $0) } ?? [:]
        visit = d.integer(forKey: "visit") + (d.object(forKey: "visit") == nil ? 0 : 1)
        d.set(visit, forKey: "visit")
    }

    func setLanguage(_ l: Lang) {
        // as in the prototype, choosing the app language also sets the report language
        lang = l; reportLang = l
        d.set(l.code, forKey: "lang"); d.set(l.code, forKey: "reportLang")
    }
    func setReportLangDefault(_ l: Lang) { reportLang = l; d.set(l.code, forKey: "reportLang") }
    func setCurrencyDefault(_ c: String) { currency = c; d.set(c, forKey: "currency") }
    func setUnit(cm: Bool) { unitCm = cm; d.set(cm ? "cm" : "m", forKey: "unit") }
    func setSnap(_ on: Bool) { angleSnap = on; d.set(on, forKey: "angleSnap") }
    func setDarkMode(_ on: Bool) { dark = on; d.set(on, forKey: "dark") }
    func setIndustryKind(_ v: String) { industry = v; d.set(v, forKey: "industry") }
    func setRoomLabel(_ v: String) { roomLabel = v; d.set(v, forKey: "roomLabel") }
    func setDefaults(_ dw: Int, _ dh: Int, _ ww: Int, _ wh: Int, _ ws: Int) {
        doorW = dw; doorH = dh; winW = ww; winH = wh; winSill = ws
        for (k, v) in [("doorW", dw), ("doorH", dh), ("winW", ww), ("winH", wh), ("winSill", ws)] { d.set(v, forKey: k) }
    }
    func saveBuilder(_ name: String, _ phone: String) {
        builderName = name.trimmingCharacters(in: .whitespacesAndNewlines); builderPhone = Phone.digits(phone)
        d.set(builderName, forKey: "builderName"); d.set(builderPhone, forKey: "builderPhone")
    }
    @discardableResult func addReading(_ mm: Int, _ src: String) -> Reading {
        let r = Reading(id: uid(), n: (readings.map(\.n).max() ?? 0) + 1, mm: mm, ts: nowMs(), src: src)
        readings.append(r); saveReadings(); return r
    }
    func deleteReading(_ id: String) { readings.removeAll { $0.id == id }; saveReadings() }
    func markReadingUsed(_ id: String, _ where_: String) { if let i = readings.firstIndex(where: { $0.id == id }) { readings[i].used = where_; saveReadings() } }
    private func saveReadings() { d.set(try? JSONEncoder().encode(readings), forKey: "readings") }
    func setBrickSpec(_ b: BrickSpec) { brick = b; d.set(try? JSONEncoder().encode(b), forKey: "brick") }
    func saveShots(_ v: [Item]) { shots = v; d.set(try? JSONEncoder().encode(v), forKey: "shots") }
    /// Profile → "Hints back": the editor's first-time tip shows again.
    func resetHints() { editorTipOff = false; d.set(false, forKey: "tipEditor") }
    func setPdfParts(_ v: PdfParts) { pdf = v; d.set(try? JSONEncoder().encode(v), forKey: "pdf") }
    func setDraft(_ key: String, _ form: [String: String]?) {
        if let form { rowDrafts[key] = form } else { rowDrafts.removeValue(forKey: key) }
        d.set(try? JSONEncoder().encode(rowDrafts), forKey: "rowDrafts")
    }
    func hideEditorTip() { editorTipOff = true; d.set(true, forKey: "tipEditor") }
    func finishFirstRun() { firstRunDone = true; d.set(true, forKey: "firstRunDone") }
}

/// The current language's text for [key] (reads the setting, so a screen follows a language change).
func tr(_ key: String, _ vars: [String: Any]? = nil) -> String { Strings.t(key, AppSettings.shared.lang, vars) }
