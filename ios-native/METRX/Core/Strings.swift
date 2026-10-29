import Foundation

/// The four app languages, in the order the prototype lists them.
enum Lang: Int, CaseIterable, Identifiable {
    case uz, uzc, ru, en
    var id: Int { rawValue }
    var code: String { ["uz", "uzc", "ru", "en"][rawValue] }
    var longName: String { ["O‘zbekcha (lotin)", "Ўзбекча (кирилл)", "Русский", "English"][rawValue] }
    var shortName: String { ["O‘zbekcha", "Ўзбекча", "Русский", "English"][rawValue] }
    /// Uzbek Cyrillic and Russian are set in Manrope, because Plus Jakarta Sans has no Cyrillic letters.
    var cyrillic: Bool { self == .uzc || self == .ru }
    static func of(_ code: String?) -> Lang { allCases.first { $0.code == code } ?? .uz }
}

/// Every screen text in four languages. strings.json is the Android app's table, extracted from the prototype
/// (key → [uz, uz-Cyrl, ru, en]); the few texts only the native apps need are in `native`.
/// Templates work as in the prototype: {name} is replaced, {n:form1|form2|form3} picks a plural form by the number n.
enum Strings {
    private static var table: [String: [String]] = {
        var t: [String: [String]] = [:]
        if let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [Any]] {
            for (k, v) in obj { t[k] = (0..<4).map { i in i < v.count ? (v[i] as? String ?? "") : "" } }
        }
        for (k, v) in native { t[k] = v }
        return t
    }()

    static func has(_ key: String) -> Bool { table[key] != nil }

    static func t(_ key: String, _ lang: Lang, _ vars: [String: Any]? = nil) -> String {
        guard let s = template(key, lang) else { return key }
        return fill(s, lang, vars)
    }

    /// key's text in lang before its values go in (Uzbek Latin when lang has none); nil for an unknown key.
    static func template(_ key: String, _ lang: Lang) -> String? {
        guard let e = table[key] else { return nil }
        return e[lang.rawValue].isEmpty ? e[0] : e[lang.rawValue]
    }

    /// A template with its values put in: plural forms first, then the names.
    static func fill(_ s0: String, _ lang: Lang, _ vars: [String: Any]?) -> String {
        var s = s0
        guard let vars else { return s }
        s = replace(s, plural) { g in
            let raw = vars[g[1]]
            // a number, or a number as text (a stored line's values: "n=1", "a=2,5")
            let txt: Double? = (raw as? String).flatMap { Double($0.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) }
            let n = (raw as? Int).map(Double.init) ?? (raw as? Double) ?? txt ?? Double(g[1]) ?? 0
            return pluralForm(n, g[2], lang)
        }
        s = replace(s, variable) { g in vars[g[1]].map { "\($0)" } ?? g[0] }
        return s
    }

    private static let plural = try! NSRegularExpression(pattern: #"\{(\w+):([^}]+)\}"#)
    private static let variable = try! NSRegularExpression(pattern: #"\{(\w+)\}"#)

    private static func replace(_ s: String, _ re: NSRegularExpression, _ f: ([String]) -> String) -> String {
        let ns = s as NSString
        var out = ""; var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += f(groups)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    private static func pluralForm(_ n: Double, _ forms: String, _ lang: Lang) -> String {
        let f = forms.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if lang == .ru {
            let a = abs(Int(n)) % 100, b = a % 10
            let i = (11...19).contains(a) ? 2 : b == 1 ? 0 : (2...4).contains(b) ? 1 : 2
            return i < f.count ? f[i] : f[f.count - 1]
        }
        return n == 1 ? f[0] : (f.count > 1 ? f[1] : f[0])
    }

    /// Texts that exist only in the native apps: [uz, uz-Cyrl, ru, en].
    private static let native: [String: [String]] = [
        "nt.soonT": ["Hisoblar tez orada", "Ҳисоблар тез орада", "Аккаунты скоро", "Accounts are coming soon"],
        "nt.soonB": [
            "Ro‘yxatdan o‘tish va kirish hali ishlamaydi. Hozircha ilova hisobsiz to‘liq ishlaydi: hammasi shu telefonda saqlanadi.",
            "Рўйхатдан ўтиш ва кириш ҳали ишламайди. Ҳозирча илова ҳисобсиз тўлиқ ишлайди: ҳаммаси шу телефонда сақланади.",
            "Регистрация и вход пока не работают. Приложение полностью работает без аккаунта: всё хранится на этом телефоне.",
            "Sign-up and log-in don’t work yet. The app works fully without an account: everything stays on this phone."
        ],
        "nt.part": ["Bu ekran {n}-qismda qo‘shiladi", "Бу экран {n}-қисмда қўшилади", "Этот экран появится в части {n}", "This screen arrives in part {n}"],
        "nt.simLaser": ["Simulyatsiya: haqiqiy lazer hali ulanmagan", "Симуляция: ҳақиқий лазер ҳали уланмаган", "Симуляция: настоящий лазер пока не подключён", "Simulation: no real laser is connected yet"],
        "nt.back": ["Orqaga", "Орқага", "Назад", "Back"],
        "nt.dark": ["Tungi rejim", "Тунги режим", "Тёмная тема", "Dark mode"],
        // the laser test page on iPhone: no classic Bluetooth for apps
        "nt.ltIos": [
            "iPhone’da faqat Bluetooth LE ishlaydi: klassik Bluetooth (SPP) iPhone ilovalariga ochiq emas, shuning uchun bu yerda yo‘q.",
            "iPhone’да фақат Bluetooth LE ишлайди: классик Bluetooth (SPP) iPhone иловаларига очиқ эмас, шунинг учун бу ерда йўқ.",
            "На iPhone работает только Bluetooth LE: классический Bluetooth (SPP) недоступен приложениям iPhone, поэтому его здесь нет.",
            "On iPhone only Bluetooth LE works: classic Bluetooth (SPP) is not open to iPhone apps, so it is not on this page."
        ],
    ]
}

/// Uzbek phone numbers: 9 digits after +998, shown as 90 123 45 67.
enum Phone {
    static func digits(_ v: String?) -> String {
        let d = (v ?? "").filter(\.isNumber)
        return d.count == 12 && d.hasPrefix("998") ? String(d.dropFirst(3)) : d
    }
    static func groups(_ v: String?) -> String {
        let d = Array(digits(v))
        return [(0, 2), (2, 5), (5, 7), (7, 9)].compactMap { a, b in d.count > a ? String(d[a..<min(b, d.count)]) : nil }.joined(separator: " ")
    }
    static func format(_ v: String?) -> String { let d = digits(v); return d.isEmpty ? "" : "+998 " + groups(d) }
    /// Typing or pasting "+998 90 123 45 67" keeps only the 9 local digits.
    static func normalise(_ v: String) -> String {
        var d = v.filter(\.isNumber)
        if d.count > 9 && d.hasPrefix("998") { d = String(d.dropFirst(3)) }
        return String(d.prefix(9))
    }
    /// nil when fine, otherwise the strings key of the error.
    static func errorKey(_ v: String?, required: Bool) -> String? {
        let d = digits(v)
        if d.isEmpty { return required ? "ph.req" : nil }
        return d.count != 9 ? "ph.len" : nil
    }
}

/// Number formats of the prototype: comma decimals, except English (point).
enum Num {
    static func dec(_ l: Lang) -> String { l == .en ? "." : "," }
    /// Lengths are stored in millimetres and shown in metres with 2 decimals (3 when the value needs it).
    static func len(_ mm: Int, _ l: Lang) -> String {
        String(format: "%.\(mm % 10 != 0 ? 3 : 2)f", Double(mm) / 1000).replacingOccurrences(of: ".", with: dec(l))
    }
    static func fixed(_ v: Double, _ decimals: Int, _ l: Lang) -> String {
        String(format: "%.\(decimals)f", v).replacingOccurrences(of: ".", with: dec(l))
    }
}
