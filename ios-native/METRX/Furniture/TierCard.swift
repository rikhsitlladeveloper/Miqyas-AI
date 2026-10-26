import SwiftUI

/*
 * "3 xil narx" (Joylan ideas, approved 26 Oct 2026; the mockup's second screen; Android ui/furniture/TierCard.kt): on
 * the Narx tab (Advanced), the order in three sets of materials, Ekonom, Standart and Premium, each priced by the usual
 * costing (Core/PriceTiers.swift), and the switch that puts all three in the customer's PDF (Project.tri).
 */

/// A board's name in the app's language: a preset's by its strings key, the workshop's own as typed.
func tierBoardName(_ id: String?, _ mats: [Mat]) -> String? {
    guard let id else { return nil }
    guard let m = mats.first(where: { $0.id == id }) ?? MAT_PRESETS.first(where: { $0.id == id }) else { return id }
    if MAT_PRESETS.contains(where: { $0.id == m.id && $0.name == m.name }) && Strings.has("mp." + m.id) { return tr("mp." + m.id) }
    return dn(m.name)
}

/// The Narx tab's card of the three price options and the PDF switch.
struct TierCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let s = AppSettings.shared
        let fs = p.furniture.filter { !$0.modules.isEmpty }
        let ps = tierPrices(fs, p.fprice, s.workshop, s.mats, s.hws, remsOf(p))
        let std = ps.first { $0.tier == "std" }?.price ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                T(tr("pt.tiers"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(tr("pt.adv"), ui(11, 700, G.cobalt2), lines: 1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(G.cobalt.opacity(0.1)))
            }
            T(tr("pt.sub"), ui(12.5, 400, G.ink2, lh: 1.4))
            let f0 = fs.first { $0.kind == "kitchen" } ?? fs.first
            let kitchen = fs.contains { $0.kind == "kitchen" }
            ForEach(ps, id: \.tier) { tp in
                TierRow(p: p, tier: tp, std: std, what: tierWhat(f0, tp.tier, kitchen: kitchen))
            }
            FToggle(label: tr("pt.pdf"), on: p.tri, id: "pt.pdf") { Store.shared.update(p.id) { $0.tri.toggle() } }
            T(tr("pt.pdfNote"), ui(12, 400, G.ink2, lh: 1.35))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
        .accessibilityIdentifier("pt.card")
    }
}

/// One tier: its name, total, the difference from Standart and what it is made of.
private struct TierRow: View {
    let p: Project
    let tier: TierPrice
    let std: Decimal
    /// What it is made of, line by line (Core/PriceTiers.swift tierWhat).
    let what: [(String, String)]
    var body: some View {
        let s = AppSettings.shared, en = s.lang == .en
        let isStd = tier.tier == "std"
        let pct = tierPct(tier.price, std)
        let delta = isStd ? tr("pt.asDesign") : tr("pt.delta", ["v": (pct > 0 ? "+" : pct < 0 ? "−" : "") + "\(abs(pct))"])
        let lines: [String] = what.map { k, v in
            let value = v.hasPrefix("#") ? (tierBoardName(String(v.dropFirst()), s.mats) ?? tr("pt.std.asIs")) : tr(v)
            return tr(k) + ": " + value
        }
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                T(tr("pt." + tier.tier), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(Money.str(tier.price, p.precision, en) + " " + Money.cur(p.currency), num(15.5, 800), lines: 1)
            }
            T(delta, ui(12, 600, isStd ? G.cobalt2 : G.ink3), lines: 1)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, ln in T("· " + ln, ui(12.5, 400, G.ink2, lh: 1.35)) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(isStd ? G.cobalt.opacity(0.07) : G.glass(0.55)))
        .overlay(shape.strokeBorder(isStd ? G.cobalt : G.rim, lineWidth: isStd ? 1.5 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pt." + tier.tier)
    }
}
