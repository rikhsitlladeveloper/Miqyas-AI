import Foundation

/*
 * Spoken sizes to millimetres (UX upgrades 26 Oct 2026, section 9; Android VoiceParse.kt): Uzbek (Latin and Cyrillic)
 * and Russian number words, "yarim" / "с половиной" / "полтора", the units metre, centimetre and millimetre, and digits as
 * said. Pure Swift, no Apple frameworks: the shared cases in design/ux-upgrades/voice-cases.json run in the unit tests.
 *
 *   "uch ming to‘rt yuz" → 3400      "ikki yarim metr" → 2500      "bir metr yigirma" → 1200
 *   "три тысячи четыреста" → 3400    "полтора метра" → 1500        "семьдесят сантиметров" → 700
 *
 * A number with no unit is millimetres, unless it is small (under 30): then metres ("uch" → 3000, "2,5" → 2500).
 * Words after a number of metres with no unit of their own are centimetres ("bir metr yigirma" → 1 m 20 cm).
 */
enum VoiceParse {
    /// The size said in text, mm; nil when no number was heard.
    static func mm(_ text: String) -> Int? {
        let toks = tokens(text)
        var total = 0.0, cur = 0.0, half = false, any = false, num = false
        var out = 0.0, lastUnit: Double? = nil, gotUnit = false
        func value() -> Double { total + cur + (half ? 0.5 : 0) }
        func reset() { total = 0; cur = 0; half = false; num = false }
        var i = 0
        while i < toks.count {
            let t = toks[i]
            i += 1
            if let d = digits(t) {
                // "3 400": a group of three digits right after a number joins it
                if num && t.count == 3 && t.allSatisfy(\.isNumber) && cur >= 1 && cur < 1000 && total == 0 { cur = cur * 1000 + d }
                else { cur += d }
                num = true; any = true; continue
            }
            if let v = SMALL[t] { cur += v; num = true; any = true; continue }
            if HUNDRED.contains(t) { cur = (cur == 0 ? 1 : cur) * 100; num = true; any = true; continue }
            if let v = HUNDREDS[t] { cur += v; num = true; any = true; continue }
            if THOUSAND.contains(t) { total += (cur == 0 ? 1 : cur) * 1000; cur = 0; num = true; any = true; continue }
            if ONE_HALF.contains(t) { cur += 1.5; num = true; any = true; continue }
            if HALF.contains(t) { half = true; any = true; continue }
            if let f = UNIT[t] {
                if num || half {
                    out += value() * f
                    reset()
                } else if f == 1000 && lastUnit == nil && out == 0 {
                    // "metr" alone after nothing: one metre
                    out += 1000
                }
                lastUnit = f; gotUnit = true
                continue
            }
            // other words ("va", "и", "с", "taxminan") are skipped
        }
        guard any else { return nil }
        if num || half {
            let v = value()
            if let u = lastUnit, u == 1000 { out += v < 100 ? v * 10 : v }       // after metres: centimetres
            else if gotUnit { out += v }                                          // after cm or mm: millimetres
            else { out += v < 30 ? v * 1000 : v }                                 // no unit: mm, a small number metres
        }
        let r = Int((out).rounded())
        return r > 0 ? r : nil
    }

    /// Lower case, one kind of apostrophe, the words and numbers ("3,4" and "3.4" kept whole).
    static func tokens(_ text: String) -> [String] {
        var s = text.lowercased()
        for a in ["‘", "’", "ʻ", "ʼ", "`", "´", "′"] { s = s.replacingOccurrences(of: a, with: "'") }
        s = s.replacingOccurrences(of: "ё", with: "е")
        var out: [String] = []
        var cur = ""
        let chars = Array(s)
        for (k, c) in chars.enumerated() {
            let digitComma = (c == "," || c == ".") && !cur.isEmpty && cur.last!.isNumber && k + 1 < chars.count && chars[k + 1].isNumber
            if c.isLetter || c.isNumber || c == "'" || digitComma {
                // a word and a number written together ("3400mm", "2m") are two tokens
                if let l = cur.last, (l.isNumber || l == "," || l == ".") != (c.isNumber || digitComma) && !(c == "'" ) {
                    out.append(cur); cur = ""
                }
                cur.append(c)
            } else if !cur.isEmpty { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        // a word's own apostrophes at its ends go
        return out.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }.filter { !$0.isEmpty }
    }

    /// A number written in digits: "3400", "3,4", "2.5".
    private static func digits(_ t: String) -> Double? {
        guard let f = t.first, f.isNumber else { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: words

    private static let SMALL: [String: Double] = {
        var m: [String: Double] = [:]
        let uz: [(String, Double)] = [
            ("nol", 0), ("bir", 1), ("ikki", 2), ("uch", 3), ("to'rt", 4), ("tort", 4), ("besh", 5), ("olti", 6), ("yetti", 7), ("etti", 7),
            ("sakkiz", 8), ("to'qqiz", 9), ("toqqiz", 9), ("o'n", 10), ("on", 10), ("yigirma", 20), ("o'ttiz", 30), ("ottiz", 30), ("qirq", 40),
            ("ellik", 50), ("oltmish", 60), ("yetmish", 70), ("etmish", 70), ("sakson", 80), ("to'qson", 90), ("toqson", 90),
        ]
        let uzc: [(String, Double)] = [
            ("нол", 0), ("бир", 1), ("икки", 2), ("уч", 3), ("тўрт", 4), ("торт", 4), ("беш", 5), ("олти", 6), ("етти", 7), ("саккиз", 8),
            ("тўққиз", 9), ("тоққиз", 9), ("ўн", 10), ("йигирма", 20), ("ўттиз", 30), ("қирқ", 40), ("эллик", 50), ("олтмиш", 60),
            ("етмиш", 70), ("саксон", 80), ("тўқсон", 90),
        ]
        let ru: [(String, Double)] = [
            ("ноль", 0), ("один", 1), ("одна", 1), ("одну", 1), ("два", 2), ("две", 2), ("три", 3), ("четыре", 4), ("пять", 5), ("шесть", 6),
            ("семь", 7), ("восемь", 8), ("девять", 9), ("десять", 10), ("одиннадцать", 11), ("двенадцать", 12), ("тринадцать", 13),
            ("четырнадцать", 14), ("пятнадцать", 15), ("шестнадцать", 16), ("семнадцать", 17), ("восемнадцать", 18), ("девятнадцать", 19),
            ("двадцать", 20), ("тридцать", 30), ("сорок", 40), ("пятьдесят", 50), ("шестьдесят", 60), ("семьдесят", 70), ("восемьдесят", 80),
            ("девяносто", 90),
        ]
        let uzTeens: [(String, Double)] = []
        for (k, v) in uz + uzc + ru + uzTeens { m[k] = v }
        return m
    }()

    /// "yuz" multiplies what is before it (uch yuz = 300).
    private static let HUNDRED: Set<String> = ["yuz", "юз"]
    /// Russian hundreds are words of their own.
    private static let HUNDREDS: [String: Double] = [
        "сто": 100, "двести": 200, "триста": 300, "четыреста": 400, "пятьсот": 500, "шестьсот": 600, "семьсот": 700, "восемьсот": 800, "девятьсот": 900,
    ]
    private static let THOUSAND: Set<String> = ["ming", "минг", "тысяча", "тысячи", "тысяч", "тысячу"]
    private static let ONE_HALF: Set<String> = ["полтора", "полторы"]
    private static let HALF: Set<String> = ["yarim", "ярим", "половиной", "половина", "половину"]
    /// A unit word: how many mm one of it is.
    private static let UNIT: [String: Double] = [
        "metr": 1000, "metrga": 1000, "metru": 1000, "m": 1000, "метр": 1000, "метра": 1000, "метров": 1000, "метре": 1000, "м": 1000,
        "sm": 10, "santimetr": 10, "santim": 10, "cm": 10, "см": 10, "сантиметр": 10, "сантиметра": 10, "сантиметров": 10, "сантиметрга": 10,
        "mm": 1, "millimetr": 1, "мм": 1, "миллиметр": 1, "миллиметра": 1, "миллиметров": 1, "миллиметрга": 1,
    ]
}
