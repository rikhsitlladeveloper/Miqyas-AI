import SwiftUI

/*
 * Help (UX upgrades 26 Oct 2026, section 11): on a furniture maker's first start three tour cards (measure with the
 * laser or the voice, the 3D gallery, sending on Telegram) with "O‘tkazib yuborish"; after it a coach mark the first
 * time on each screen (order, gallery, size, designer, price), pointing at the one thing to press. Profile →
 * "Maslahatlarni qayta ko‘rsatish" brings them back with the sample order.
 */

/// Where the coach marks point: screen key → the target's bounds.
struct CoachKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) { value.merge(nextValue()) { a, _ in a } }
}

extension View {
    /// The target of screen key's coach mark ("" none); shown once, after the tour.
    @ViewBuilder func coachMark(_ key: String) -> some View {
        if key.isEmpty { self } else { anchorPreference(key: CoachKey.self, value: .bounds) { [key: $0] } }
    }
}

/// The coach mark of the first due target on screen: a ring round it, a bubble with "Tushunarli"; a tap anywhere closes it.
struct CoachLayer: View {
    let marks: [String: Anchor<CGRect>]
    @State private var shown: String? = nil
    @State private var ready: String? = nil
    var body: some View {
        let s = AppSettings.shared
        let order = ["order", "gallery", "size", "designer", "price"]
        // after any sheet and toast has gone, so the mark never hides what was just said
        let quiet = AppModel.shared.sheet == nil && AppModel.shared.toast == nil
        let due = quiet && s.furniture ? order.first { marks[$0] != nil && s.coachDue($0) } : nil
        GeometryReader { geo in
            if let k = due, ready == k, let a = marks[k] {
                let r = geo[a].insetBy(dx: -6, dy: -6)
                let below = r.midY < geo.size.height / 2
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                    VStack(alignment: .leading, spacing: 6) {
                        T(tr("ux.coach." + k + ".t"), ui(16, 800, G.ink))
                        T(tr("ux.coach." + k + ".b"), ui(13.5, 400, G.ink2, lh: 1.4))
                        HStack { Spacer(); GBtn(tr("ux.gotIt"), height: 44, corner: 14, fontSize: 14.5, fill: false) { close(k) }.accessibilityIdentifier("ux.coachOk") }
                    }
                    .padding(14)
                    .frame(width: min(geo.size.width - 32, 340), alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.solid))
                    .boxShadow(Color.black.opacity(0.25), blur: 24, y: 8)
                    .offset(x: 16, y: below ? r.maxY + 12 : max(8, r.minY - 160))
                }
                .contentShape(Rectangle())
                .onTapGesture { close(k) }
                .transition(.opacity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ux.coach")
            }
        }
        .allowsHitTesting(due != nil && ready == due)
        .onChange(of: due, initial: true) { _, k in
            ready = nil
            guard let k else { return }
            // after the page has slid in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if k == due { withAnimation(.easeOut(duration: 0.2)) { ready = k } } }
        }
    }
    private func close(_ k: String) {
        AppSettings.shared.markCoach(k)
        withAnimation(.easeOut(duration: 0.2)) { ready = nil }
    }
}

/// The three tour cards over Home on a furniture maker's first start.
struct TourOverlay: View {
    @State private var i = 0
    var body: some View {
        let last = i == 2
        ZStack {
            G.scrim.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt.opacity(0.1))
                    picture
                }
                .frame(height: 150)
                T("\(i + 1) / 3", ui(12.5, 700, G.cobalt2))
                T(tr("ux.tour\(i + 1).t"), ui(21, 800, G.ink, lh: 1.2))
                T(tr("ux.tour\(i + 1).b"), ui(14.5, 400, G.ink2, lh: 1.45)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { k in Capsule().fill(k == i ? G.cobalt : G.ink.opacity(0.15)).frame(width: k == i ? 18 : 7, height: 7) }
                    }
                    Spacer()
                    if !last {
                        T(tr("ux.skip"), ui(14.5, 700, G.ink2)).padding(.horizontal, 10).frame(minHeight: 48)
                            .pressable(0.97) { done() }
                            .accessibilityAddTraits(.isButton).accessibilityIdentifier("ux.tourSkip")
                    }
                    GBtn(tr(last ? "ux.start" : "common.next"), height: 48, corner: 15, fontSize: 15, fill: false) {
                        Haptic.tick()
                        if last { done() } else { withAnimation(.easeOut(duration: 0.2)) { i += 1 } }
                    }
                    .accessibilityIdentifier("ux.tourNext")
                }
                .padding(.top, 4)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(G.solid))
            .boxShadow(Color.black.opacity(0.3), blur: 40, y: 16)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ux.tour")
        }
        .transition(.opacity)
    }

    @ViewBuilder private var picture: some View {
        switch i {
        case 0:
            HStack(spacing: 18) {
                VStack(spacing: 0) { T("3400", num(34, 800)); T(tr("u.mm"), ui(12, 600, G.ink3)) }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.solid))
                ZStack { Circle().fill(G.ink); PathIcon(MIC_ICON, .white, 30, 2.2) }.frame(width: 66, height: 66)
                ZStack { Circle().fill(G.cobalt); MIcon("laser", .white, 28, 2.2) }.frame(width: 50, height: 50)
            }
        case 1:
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { k in
                    MIcon(k == 1 ? "kitchen" : k == 0 ? "cube" : "board", G.cobalt, 34, 2)
                        .frame(width: 72, height: 72)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.solid))
                }
            }
        default:
            HStack(spacing: 18) {
                MIcon("doc", G.ink, 40, 2).frame(width: 70, height: 88)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.solid))
                ZStack { Circle().fill(Color(argb: 0xFF2AABEE)); MIcon("send", .white, 30, 2.2) }.frame(width: 72, height: 72)
            }
        }
    }

    private func done() {
        Haptic.tick()
        withAnimation(.easeOut(duration: 0.22)) { AppSettings.shared.setTourDone(true) }
    }
}

/// A microphone (24-unit path).
let MIC_ICON = "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z M5 11a7 7 0 0 0 14 0 M12 18v3"
