import SwiftUI
import UIKit

/*
 * The customer's PDF: the three price options (Joylan ideas, 26 Oct 2026; the mockup's "PDF ko‘rinishi"; Android
 * report/TierPages.kt). Under the price, when the order asks for it (Project.tri, the quote's price lines pt.*): one
 * column a tier with what it is made of and its total, Standart marked as recommended, then "Mijoz tanlaydi" with a box
 * a tier and a place to sign. The same drawing and sizes in all three.
 */

private let TP_RULE = Color(argb: 0xFF9AA8BF)
private let TP_INK3 = UIColor(red: 0x3E / 255, green: 0x4A / 255, blue: 0x61 / 255, alpha: 1)

extension Doc {
    /// A board's name in the report's language: the quote's own list, else the presets.
    func tierMatName(_ id: String?, _ sn: Snap) -> String? {
        guard let id else { return nil }
        guard let m = sn.fmats.first(where: { $0.id == id }) ?? MAT_PRESETS.first(where: { $0.id == id }) else { return id }
        if MAT_PRESETS.contains(where: { $0.id == m.id && $0.name == m.name }) && Strings.has("mp." + m.id) { return t("mp." + m.id) }
        return dn(m.name, l)
    }

    /// The three price options, when the quote has their lines.
    func tierBlock(_ sn: Snap) {
        var amount: [String: Decimal] = [:]
        for ln in sn.flines where isTierLine(ln) { amount[String(ln.key.dropFirst(3))] = Decimal(string: ln.amount) ?? 0 }
        guard PRICE_TIERS.allSatisfy({ amount[$0] != nil }) else { return }
        ensure(240)
        h2(t("pt.pdfT"))
        para(a(t("pt.pdfS"), ui(9.5, 400, TP_INK3)), top: 0, bottom: 4)
        let cur = Money.cur(sn.currency, l)
        let mats = PRICE_TIERS.map { tierMats(sn.furniture, $0) }
        var rows: [[Cell]] = []
        rows.append(PRICE_TIERS.map { tr0 in th(t("pt." + tr0) + (tr0 == "std" ? " · " + t("pt.rec") : "")) })
        rows.append(mats.map { cell(tierMatName($0.front, sn) ?? "—") })
        if mats.contains(where: { $0.top != nil }) { rows.append(mats.map { cell(tierMatName($0.top, sn).map { t("mt.wtK") + ": " + $0 } ?? "—") }) }
        if mats.contains(where: { $0.splash != nil }) { rows.append(mats.map { cell(tierMatName($0.splash, sn).map { t("mt.splashK") + ": " + $0 } ?? "—") }) }
        rows.append(mats.map { cell(t($0.hw) + ($0.led ? " · " + t("pt.led") : "")) })
        rows.append(PRICE_TIERS.map { tr0 in Cell([a(money(amount[tr0] ?? 0) + " " + cur, num(11, 700))], right: true, dbl: true) })
        table(rows, fixed: [CW / 3, CW / 3, CW / 3], head: 1, breakable: false)
        // the customer's choice: a box a tier, and the signature
        ensure(64)
        space(8)
        let lab = a(t("pt.choose"), ui(10, 700)), labS = measure(lab, CW)
        let top = y
        text(lab, CGRect(x: PX, y: top, width: CW, height: labS.height))
        let by = top + labS.height + 6
        var x = PX
        var rowH: CGFloat = 0
        for tr0 in PRICE_TIERS {
            let s = a(t("pt." + tr0), ui(10)), sz = measure(s)
            let bx = x
            rowH = max(rowH, sz.height)
            draw { ctx in
                let r = CGRect(x: bx, y: by + (sz.height - 10) / 2, width: 10, height: 10)
                ctx.stroke(Path(r), with: .color(TP_RULE), lineWidth: 0.9)
            }
            text(s, CGRect(x: bx + 15, y: by, width: sz.width + 2, height: sz.height))
            x += 15 + sz.width + 24
        }
        y = by + rowH
        after(4)
        para(a(t("pt.sign"), ui(9.5, 400, TP_INK3)), top: 6, bottom: 10)
    }
}
