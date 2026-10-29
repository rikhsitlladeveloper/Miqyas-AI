import Foundation

/*
 * The room flow's and the room editor's lengths in the role's unit (founder 29 Oct 2026): a builder's metres (or the
 * centimetres chosen in Profile), a furniture maker's millimetres. The sizes are kept in mm; only what is shown and
 * typed changes. Most texts take their values already in the unit (reLen); the shared texts still say "mm" after them
 * and some name fixed sizes ("300 mm", "999 999 mm", "80 / 100 / 120 / 250"), so reTr puts the unit into a text's
 * template before its values go in. Pure Swift (unitTemplate), unit-tested (RoleUnitsTests).
 */

/// A number before "mm" in a template: "300", "999 999", "999,999" (thousands apart by a space, a no-break space or a
/// comma), and the unit word itself (Latin or Cyrillic) as a word of its own.
private let UT_N = "(\\d{1,3}(?:[ \\u00A0\\u202F,]\\d{3})+|\\d+)"
private let UT_NUM_MM = try! NSRegularExpression(pattern: UT_N + "[ \\u00A0]?(mm|мм)(?![\\p{L}\\d])")
/// A range written out, "300 – 999 999 mm", "От 300 до 999 999 мм", "300 to 999,999 mm": both ends.
private let UT_RANGE = try! NSRegularExpression(pattern: "(\\d+)(\\s(?:–|-|to|до)\\s)" + UT_N + "[ \\u00A0]?(mm|мм)(?![\\p{L}\\d])")
private let UT_MM = try! NSRegularExpression(pattern: "(?<![\\p{L}\\d])(mm|мм)(?![\\p{L}\\d])")
/// "(80 / 100 / 120 / 250)" (the inner walls' thicknesses), "standart 100" (their usual one).
private let UT_LIST = try! NSRegularExpression(pattern: "\\((\\d+(?: / \\d+)+)\\)")
private let UT_STD = try! NSRegularExpression(pattern: "((?:standart|standard|стандарт)\\s)(\\d+)(?![\\d,.])")

/// The template s with its millimetres in unit: a fixed size written in it ("300 mm") turned into the unit ("0,30 m"),
/// "mm" after a value's place ("{v} mm") into the unit's word, the thickness list and "standart 100" into the unit too.
/// word: the unit's word in the text's language ("m", "м", "sm"). In mm nothing changes.
func unitTemplate(_ s: String, _ unit: LenUnit, _ en: Bool, word: String) -> String {
    if unit == .mm || (!s.contains("mm") && !s.contains("мм")) { return s }
    func len(_ digits: String) -> String {
        let n = Int(digits.filter(\.isNumber)) ?? 0
        return Geo.fmtLen(n, unit, en)
    }
    var out = utReplace(s, UT_RANGE) { g in len(g[1]) + g[2] + len(g[3]) + " " + word }
    out = utReplace(out, UT_NUM_MM) { g in len(g[1]) + " " + word }
    out = utReplace(out, UT_LIST) { g in "(" + g[1].components(separatedBy: " / ").map(len).joined(separator: " / ") + ")" }
    out = utReplace(out, UT_STD) { g in g[1] + len(g[2]) }
    out = utReplace(out, UT_MM) { _ in word }
    return out
}

private func utReplace(_ s: String, _ re: NSRegularExpression, _ f: ([String]) -> String) -> String {
    let ns = s as NSString
    var out = "", last = 0
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

/// A room text in the app's language with its lengths in the role's unit (its values given already in the unit, as
/// reLen writes them).
func reTr(_ key: String, _ vars: [String: Any]? = nil) -> String {
    let s = AppSettings.shared
    guard let tpl = Strings.template(key, s.lang) else { return key }
    return Strings.fill(unitTemplate(tpl, s.unit, s.lang == .en, word: unitWord(s.unit)), s.lang, vars)
}
