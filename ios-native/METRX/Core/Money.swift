import Foundation

/*
 * Money and quantities as the prototype keeps them (Android core/Money.kt): typed text stored in a canonical form
 * ("150", "12.5"), read back as whole numbers of the smallest unit, so no sum is ever rounded by floating point.
 * The prototype and the Android app use big integers; here Decimal, which holds 38 digits exactly. Quantities have
 * 3 decimals; prices and amounts the project's precision (0 for so'm).
 */
enum Dec: Equatable {
    case ok(Decimal)
    case empty, format, negative
    /// More decimals than allowed; n = how many are allowed (0: a whole number).
    case precision(Int)
    var value: Decimal? { if case .ok(let v) = self { return v }; return nil }
}

enum Money {
    private static let spaces = try! NSRegularExpression(pattern: "[\\s\u{00A0}\u{202F}]")
    private static func strip(_ s: String) -> String { spaces.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "") }
    private static func matches(_ s: String, _ p: String) -> Bool { s.range(of: p, options: .regularExpression) != nil }

    /// prototype parseDec: "4,25", "4.25", "120 000"; maxDec digits after the mark at most.
    static func parse(_ str: String?, _ maxDec: Int) -> Dec {
        var s = strip(str ?? "")
        if s.isEmpty { return .empty }
        if !matches(s, "^-?\\d*([.,]\\d*)?$") || matches(s, "^-?[.,]?$") { return .format }
        if s.hasPrefix("-") { return .negative }
        s = s.replacingOccurrences(of: ",", with: ".")
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let i = parts[0], f = parts.count > 1 ? parts[1] : ""
        if f.count > maxDec { return .precision(maxDec) }
        return .ok(Decimal(string: (i.isEmpty ? "0" : i) + f.padding(toLength: maxDec, withPad: "0", startingAt: 0)) ?? 0)
    }

    /// prototype canonOf: what is stored ("120 000" → "120000", "4,50" → "4.50", "007" → "7", "5." → "5").
    static func canon(_ str: String) -> String {
        var s = strip(str).replacingOccurrences(of: ",", with: ".")
        while s.count > 1 && s.hasPrefix("0") && s.dropFirst().first?.isNumber == true { s.removeFirst() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private static func dec(_ en: Bool) -> String { en ? "." : "," }
    private static func group(_ s: String, _ en: Bool) -> String {
        var out = ""
        for (i, ch) in s.enumerated() {
            if i > 0 && (s.count - i) % 3 == 0 { out += en ? "," : " " }
            out.append(ch)
        }
        return out
    }

    /// The digits of a whole Decimal ("18000000").
    static func digits(_ v: Decimal) -> String { NSDecimalNumber(decimal: v).stringValue }

    /// prototype moneyStr: 18000000 → "18 000 000"; with precision 2, 1850 → "18,50".
    static func str(_ v: Decimal, _ precision: Int, _ en: Bool) -> String {
        let neg = v < 0
        var s = digits(neg ? -v : v)
        while s.count < precision + 1 { s = "0" + s }
        let ip = String(s.prefix(s.count - precision)), fp = precision > 0 ? String(s.suffix(precision)) : ""
        return (neg ? "−" : "") + group(ip, en) + (precision > 0 ? dec(en) + fp : "")
    }

    /// prototype fmtNumStr: a stored quantity for display ("1500.5" → "1 500,5").
    static func num(_ canon: String?, _ en: Bool) -> String {
        guard let canon, !canon.isEmpty else { return "" }
        let parts = canon.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        return group(parts[0], en) + (parts.count > 1 && !parts[1].isEmpty ? dec(en) + parts[1] : "")
    }

    /// x / 1000 rounded half up (amounts are never negative).
    private static func perMille(_ x: Decimal) -> Decimal {
        var q = x / 1000, r = Decimal()
        NSDecimalRound(&r, &q, 0, .plain)
        return r
    }

    /// Quantity × price, rounded half up to the price's precision (prototype lineTotal: quantities have 3 decimals).
    static func line(_ qty: String?, _ price: String?, _ precision: Int) -> Decimal {
        guard let q = parse(qty, 3).value, let p = parse(price, precision).value else { return 0 }
        return perMille(q * p)
    }

    /// +10 % on a typed quantity, to 3 decimals (prototype resQ: Math.round(n · 1.1 · 1000) / 1000).
    static func withSpare(_ q: String) -> String {
        guard let v = parse(q, 3).value else { return canon(q) }
        // v is thousandths; v · 1.1 rounded half up to whole thousandths
        let t = perMille(v * 1100)
        let s = digits(t).count < 4 ? String(repeating: "0", count: 4 - digits(t).count) + digits(t) : digits(t)
        var ip = String(s.dropLast(3)), fp = String(s.suffix(3))
        while fp.hasSuffix("0") { fp.removeLast() }
        if ip.isEmpty { ip = "0" }
        return fp.isEmpty ? ip : ip + "." + fp
    }

    struct Totals { let m: Decimal; let l: Decimal; var g: Decimal { m + l } }

    /// Materials, labour and the grand total of a project (prototype totals).
    static func totals(_ p: Project) -> Totals {
        var m: Decimal = 0, l: Decimal = 0
        for r in p.estimate.materials { m += line(r.qty, r.price, p.precision) }
        for r in p.estimate.labor { if let v = parse(r.amount, p.precision).value { l += v } }
        return Totals(m: m, l: l)
    }

    /// "so‘m" for UZS, the code for other currencies (prototype curSuffix).
    static func cur(_ c: String, _ l: Lang = AppSettings.shared.lang) -> String { c == "UZS" ? Strings.t("cur.UZS", l) : c }

    /// A project's money for display, with its currency when asked.
    static func of(_ v: Decimal, _ p: Project, withCur: Bool = false) -> String {
        let en = AppSettings.shared.lang == .en
        return str(v, p.precision, en) + (withCur ? " " + cur(p.currency) : "")
    }

    /// The short estimate figure on project cards (prototype pcMoney): "—" when nothing, "19,5" + "mln" for a million
    /// so'm and more, else the full number and the currency code. Returns the number and its small unit.
    static func short(_ p: Project, _ g: Decimal, _ en: Bool, _ mln: String) -> (String, String?) {
        if g == 0 { return ("—", nil) }
        var v = g
        for _ in 0..<p.precision { v /= 10 }
        let d = NSDecimalNumber(decimal: v).doubleValue
        if p.currency == "UZS" && d >= 1e6 {
            var s = String(format: "%.2f", d / 1e6)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            return (s.replacingOccurrences(of: ".", with: dec(en)), mln)
        }
        return (str(g, p.precision, en), p.currency)
    }
}
